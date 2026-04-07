import { useEffect, useRef, useState } from 'react';
import { io, Socket } from 'socket.io-client';

interface UseWebSocketOptions {
  token?: string;
  autoConnect?: boolean;
  onConnect?: () => void;
  onDisconnect?: () => void;
  onError?: (error: Error) => void;
}

export function useWebSocket(options: UseWebSocketOptions = {}) {
  const {
    token,
    autoConnect = true,
    onConnect,
    onDisconnect,
    onError,
  } = options;

  const [isConnected, setIsConnected] = useState(false);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const socketRef = useRef<Socket | null>(null);

  useEffect(() => {
    if (!autoConnect) return;

    const socket = io({
      path: '/api/ws',
      autoConnect: false,
    });

    socketRef.current = socket;

    socket.on('connect', () => {
      setIsConnected(true);
      onConnect?.();
      if (token) {
        socket.emit('authenticate', token);
      }
    });

    socket.on('disconnect', () => {
      setIsConnected(false);
      setIsAuthenticated(false);
      onDisconnect?.();
    });

    socket.on('authenticated', () => {
      setIsAuthenticated(true);
    });

    socket.on('auth_error', (data) => {
      onError?.(new Error(data.message));
      socket.disconnect();
    });

    socket.on('connect_error', (error) => {
      onError?.(error);
    });

    socket.connect();

    return () => {
      socket.disconnect();
      socketRef.current = null;
    };
  }, [autoConnect, token]);

  const subscribe = (channel: string, callback: (data: any) => void) => {
    if (!socketRef.current) return;

    socketRef.current.emit('subscribe', channel);
    socketRef.current.on(channel, callback);

    return () => {
      socketRef.current?.off(channel, callback);
      socketRef.current?.emit('unsubscribe', channel);
    };
  };

  const emit = (event: string, data: any) => {
    if (!socketRef.current || !isConnected) {
      return;
    }
    socketRef.current.emit(event, data);
  };

  const on = (event: string, callback: (data: any) => void) => {
    if (!socketRef.current) return;

    socketRef.current.on(event, callback);

    return () => {
      socketRef.current?.off(event, callback);
    };
  };

  return {
    isConnected,
    isAuthenticated,
    subscribe,
    emit,
    on,
  };
}
