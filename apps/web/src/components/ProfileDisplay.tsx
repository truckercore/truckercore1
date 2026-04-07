'use client';

import { useProfile } from "@/hooks/useProfile";

export const ProfileDisplay = () => {
  const profile = useProfile();

  if (!profile) {
    return <p className="text-gray-500">Please log in to see your profile.</p>;
  }

  return (
    <div className="p-4 border rounded shadow">
      <h2 className="font-bold text-lg">Welcome, {profile.username || profile.email}!</h2>
      <p>ID: {profile.id}</p>
    </div>
  );
};
