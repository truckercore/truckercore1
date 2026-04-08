'use client';

import { useState, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirectTo = searchParams.get('redirectTo') || '/';

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);
  const [mode, setMode] = useState<'signin' | 'signup'>('signin');

  const handleSubmit = async () => {
    if (!email || !password) {
      setMessage('Email and password are required');
      return;
    }
    setLoading(true);
    setMessage('');
    const supabase = createClient();
    const { error } = mode === 'signin'
      ? await supabase.auth.signInWithPassword({ email, password })
      : await supabase.auth.signUp({ email, password });
    if (error) {
      setMessage(error.message);
      setLoading(false);
      return;
    }
    if (mode === 'signup') {
      setMessage('Check your email for confirmation link');
      setLoading(false);
      return;
    }
    router.push(redirectTo);
    router.refresh();
  };

  return (
    <div className="min-h-screen bg-gray-950 flex items-center justify-center">
      <div className="bg-gray-900 border border-gray-800 rounded-2xl p-8 w-full max-w-md">
        <h1 className="text-2xl font-bold text-white mb-1">TruckerCore</h1>
        <p className="text-gray-400 text-sm mb-6">
          {mode === 'signin' ? 'Sign in to your account' : 'Create your account'}
        </p>
        {message && (
          <p className={`text-sm mb-4 ${message.toLowerCase().includes('check your email') ? 'text-yellow-400' : 'text-red-400'}`}>
            {message}
          </p>
        )}
        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="w-full bg-gray-800 border border-gray-700 text-white rounded-lg px-4 py-3 mb-3 focus:outline-none focus:border-blue-500"
        />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') handleSubmit(); }}
          className="w-full bg-gray-800 border border-gray-700 text-white rounded-lg px-4 py-3 mb-4 focus:outline-none focus:border-blue-500"
        />
        <button
          onClick={handleSubmit}
          disabled={loading}
          className="w-full bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white font-medium rounded-lg py-3 mb-3 transition"
        >
          {loading ? 'Please wait...' : mode === 'signin' ? 'Sign In' : 'Create Account'}
        </button>
        <button
          onClick={() => { setMode(mode === 'signin' ? 'signup' : 'signin'); setMessage(''); }}
          className="w-full bg-gray-800 hover:bg-gray-700 text-gray-300 font-medium rounded-lg py-3 transition"
        >
          {mode === 'signin' ? 'Create Account' : 'Back to Sign In'}
        </button>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-gray-950" />}>
      <LoginForm />
    </Suspense>
  );
}
