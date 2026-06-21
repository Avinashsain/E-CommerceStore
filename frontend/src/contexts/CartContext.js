import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { cartService } from '../services/api';
import { useAuth } from './AuthContext';

const CartContext = createContext();

export const useCart = () => {
  const context = useContext(CartContext);
  if (!context) {
    throw new Error('useCart must be used within a CartProvider');
  }
  return context;
};

export const CartProvider = ({ children }) => {
  const { user } = useAuth();
  const [cart, setCart] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const loadCart = useCallback(async () => {
    if (!user) return;

    try {
      setLoading(true);
      setError(null);
      const response = await cartService.getCart(user._id);
      setCart(response.data);
    } catch (err) {
      console.error('Load cart error:', err);
      setError('Failed to load cart');
    } finally {
      setLoading(false);
    }
  }, [user]);

  // Load cart when user changes
  useEffect(() => {
    if (user) {
      loadCart();
    } else {
      setCart(null);
    }
  }, [user, loadCart]);

  const addToCart = async (productId, quantity = 1) => {
    if (!user) {
      setError('Please login to add items to cart');
      return { success: false, error: 'Please login to add items to cart' };
    }

    try {
      setError(null);
      const response = await cartService.addToCart(user._id, { productId, quantity });
      setCart(response.data.cart);
      return { success: true };
    } catch (err) {
      const message = err.response?.data?.message || 'Failed to add item to cart';
      setError(message);
      return { success: false, error: message };
    }
  };

  const updateCartItem = async (productId, quantity) => {
    if (!user) return { success: false, error: 'Please login' };

    try {
      setError(null);
      const response = await cartService.updateCartItem(user._id, productId, { quantity });
      setCart(response.data.cart);
      return { success: true };
    } catch (err) {
      const message = err.response?.data?.message || 'Failed to update cart item';
      setError(message);
      return { success: false, error: message };
    }
  };

  const removeFromCart = async (productId) => {
    if (!user) return { success: false, error: 'Please login' };

    try {
      setError(null);
      const response = await cartService.removeFromCart(user._id, productId);
      setCart(response.data.cart);
      return { success: true };
    } catch (err) {
      const message = err.response?.data?.message || 'Failed to remove item from cart';
      setError(message);
      return { success: false, error: message };
    }
  };

  const clearCart = async () => {
    if (!user) return { success: false, error: 'Please login' };

    try {
      setError(null);
      const response = await cartService.clearCart(user._id);
      setCart(response.data.cart);
      return { success: true };
    } catch (err) {
      const message = err.response?.data?.message || 'Failed to clear cart';
      setError(message);
      return { success: false, error: message };
    }
  };

  const validateCart = async () => {
    if (!user || !cart || cart.items.length === 0) {
      return { isValid: false, validationResults: [] };
    }

    try {
      setError(null);
      const response = await cartService.validateCart(user._id);
      return response.data;
    } catch (err) {
      console.error('Validate cart error:', err);
      return { isValid: false, validationResults: [] };
    }
  };

  const getCartItemsCount = () => cart?.totalItems || 0;
  const getCartTotal = () => cart?.totalPrice || 0;

  const value = {
    cart,
    loading,
    error,
    addToCart,
    updateCartItem,
    removeFromCart,
    clearCart,
    validateCart,
    loadCart,
    getCartItemsCount,
    getCartTotal,
    setError
  };

  return (
    <CartContext.Provider value={value}>
      {children}
    </CartContext.Provider>
  );
};