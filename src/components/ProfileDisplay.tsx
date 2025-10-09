import React from "react";
import { useProfile } from "../hooks/useProfile";

const ProfileDisplay: React.FC<{ orgId: string | null }> = ({ orgId }) => {
  const { features, loading } = useProfile(orgId);

  if (loading) return <p>Loading profile...</p>;
  if (!features) return <p>No profile available. Log in and try again.</p>;

  return (
    <div>
      <h2>Learned Profile</h2>
      <pre style={{ whiteSpace: "pre-wrap" }}>{JSON.stringify(features, null, 2)}</pre>
    </div>
  );
};

export default ProfileDisplay;
