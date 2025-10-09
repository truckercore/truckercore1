'use client';

import { useEventLogging } from "@/hooks/useEventLogging";

interface PlanButtonProps {
  planType: string;
  destination: string;
}

export const PlanButton = ({ planType, destination }: PlanButtonProps) => {
  const logEvent = useEventLogging();

  const handlePlanClick = async () => {
    await logEvent("plan_route", { plan_type: planType, destination });
    alert(`Planning a ${planType} route to ${destination}!`);
  };

  return (
    <button
      onClick={handlePlanClick}
      className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
    >
      Plan {planType} Route to {destination}
    </button>
  );
};
