const express = require('express');
const axios = require('axios');
const Order = require('../models/Order');

const router = express.Router();

// Service URLs
const CART_SERVICE_URL = process.env.CART_SERVICE_URL || 'http://localhost:3003';
const PRODUCT_SERVICE_URL = process.env.PRODUCT_SERVICE_URL || 'http://localhost:3002';
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://localhost:3001';

// Helper function to get cart details
const getCartDetails = async (userId) => {
  try {
    const response = await axios.get(`${CART_SERVICE_URL}/api/cart/${userId}`);
    return response.data;
  } catch (error) {
    console.error('Error fetching cart details:', error.message);
    return null;
  }
};

// Helper function to update product stock
const updateProductStock = async (productId, quantity, operation = 'subtract') => {
  try {
    await axios.post(`${PRODUCT_SERVICE_URL}/api/products/${productId}/stock`, {
      stock: quantity,
      operation
    });
    return true;
  } catch (error) {
    console.error('Error updating product stock:', error.message);
    return false;
  }
};

// Helper function to clear cart
const clearCart = async (userId) => {
  try {
    await axios.delete(`${CART_SERVICE_URL}/api/cart/${userId}`);
    return true;
  } catch (error) {
    console.error('Error clearing cart:', error.message);
    return false;
  }
};

// @route   GET /api/orders/user/:userId
// @desc    Get user's orders
// @access  Private
router.get('/user/:userId', async (req, res) => {
  try {
    const { page = 1, limit = 10, status } = req.query;
    
    const filter = { userId: req.params.userId };
    if (status) filter.status = status;

    const orders = await Order.find(filter)
      .sort({ createdAt: -1 })
      .limit(limit * 1)
      .skip((page - 1) * limit)
      .exec();

    const total = await Order.countDocuments(filter);

    res.json({
      orders,
      totalPages: Math.ceil(total / limit),
      currentPage: page,
      total
    });

  } catch (error) {
    console.error('Get orders error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   GET /api/orders/:id
// @desc    Get single order
// @access  Private
router.get('/:id', async (req, res) => {
  try {
    const order = await Order.findById(req.params.id);
    
    if (!order) {
      return res.status(404).json({ message: 'Order not found' });
    }

    res.json(order);
  } catch (error) {
    console.error('Get order error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/orders
// @desc    Create new order
// @access  Private
router.post('/', async (req, res) => {
  try {
    const {
      userId,
      shippingAddress,
      billingAddress,
      paymentMethod,
      shippingMethod = 'standard',
      customerNotes
    } = req.body;

    // Get cart details
    const cart = await getCartDetails(userId);
    if (!cart || cart.items.length === 0) {
      return res.status(400).json({ message: 'Cart is empty' });
    }

    // Validate cart items (check stock, prices)
    const validationResponse = await axios.post(`${CART_SERVICE_URL}/api/cart/${userId}/validate`);
    if (!validationResponse.data.isValid) {
      return res.status(400).json({
        message: 'Cart validation failed',
        validationResults: validationResponse.data.validationResults
      });
    }

    // Calculate shipping and tax
    const shipping = calculateShipping(shippingMethod, cart.totalPrice);
    const tax = calculateTax(cart.totalPrice, shippingAddress.state);

    // Create order
    const order = new Order({
      userId,
      items: cart.items.map(item => ({
        productId: item.productId,
        quantity: item.quantity,
        price: item.price,
        total: item.quantity * item.price,
        productDetails: item.productDetails
      })),
      pricing: {
        subtotal: cart.totalPrice,
        tax,
        shipping,
        total: cart.totalPrice + tax + shipping
      },
      shippingAddress,
      billingAddress: billingAddress || shippingAddress,
      paymentMethod,
      shipping: {
        method: shippingMethod,
        estimatedDelivery: calculateEstimatedDelivery(shippingMethod)
      },
      customerNotes
    });

    await order.save();

    // Update product stock for each item
    for (const item of cart.items) {
      await updateProductStock(item.productId, item.quantity, 'subtract');
    }

    // Clear the cart
    await clearCart(userId);

    res.status(201).json({
      message: 'Order created successfully',
      order
    });

  } catch (error) {
    console.error('Create order error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   PUT /api/orders/:id/status
// @desc    Update order status
// @access  Admin
router.put('/:id/status', async (req, res) => {
  try {
    const { status, trackingNumber, carrier, reason } = req.body;
    
    const order = await Order.findById(req.params.id);
    if (!order) {
      return res.status(404).json({ message: 'Order not found' });
    }

    if (status === 'shipped' && trackingNumber) {
      order.markAsShipped(trackingNumber, carrier);
    } else if (status === 'delivered') {
      order.markAsDelivered();
    } else if (status === 'cancelled') {
      order.cancelOrder(reason);
      
      // Restore product stock
      for (const item of order.items) {
        await updateProductStock(item.productId, item.quantity, 'add');
      }
    } else {
      order.status = status;
    }

    await order.save();

    res.json({
      message: 'Order status updated successfully',
      order
    });

  } catch (error) {
    console.error('Update order status error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   DELETE /api/orders/:id
// @desc    Cancel order
// @access  Private
router.delete('/:id', async (req, res) => {
  try {
    const { reason = 'Cancelled by customer' } = req.body;
    
    const order = await Order.findById(req.params.id);
    if (!order) {
      return res.status(404).json({ message: 'Order not found' });
    }

    // Only allow cancellation if order is not shipped
    if (['shipped', 'delivered'].includes(order.status)) {
      return res.status(400).json({ 
        message: 'Cannot cancel order that has already been shipped' 
      });
    }

    order.cancelOrder(reason);
    await order.save();

    // Restore product stock
    for (const item of order.items) {
      await updateProductStock(item.productId, item.quantity, 'add');
    }

    res.json({
      message: 'Order cancelled successfully',
      order
    });

  } catch (error) {
    console.error('Cancel order error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Helper functions
function calculateShipping(method, subtotal) {
  const rates = {
    standard: subtotal > 50 ? 0 : 9.99,
    express: 19.99,
    overnight: 39.99
  };
  return rates[method] || rates.standard;
}

function calculateTax(subtotal, state) {
  const taxRates = {
    'CA': 0.0875,
    'NY': 0.08,
    'TX': 0.0625,
    'FL': 0.06
  };
  const rate = taxRates[state] || 0.05; // Default 5%
  return Math.round(subtotal * rate * 100) / 100;
}

function calculateEstimatedDelivery(method) {
  const days = {
    standard: 7,
    express: 3,
    overnight: 1
  };
  const deliveryDays = days[method] || 7;
  const deliveryDate = new Date();
  deliveryDate.setDate(deliveryDate.getDate() + deliveryDays);
  return deliveryDate;
}

module.exports = router;