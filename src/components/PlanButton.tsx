import React from "react";
import { useLogEvent } from "../hooks/useLogEvent";

type Props = {
  orgId: string | null;
  origin_zip: string;
  dest_zip: string;
  deadhead_miles?: number;
  tolls?: boolean;
  pickup_time_local?: string; // ISO string
};

const PlanButton: React.FC<Props> = (props) => {
  const { logEvent } = useLogEvent(props.orgId);

  const handlePlanClick = async () => {
    await logEvent("route_planned", {
      origin_zip: props.origin_zip,
      dest_zip: props.dest_zip,
      deadhead_miles: props.deadhead_miles ?? null,
      tolls: !!props.tolls,
      pickup_time_local: props.pickup_time_local ?? null,
    });
    alert(`Planning route ${props.origin_zip} ➜ ${props.dest_zip}`);
  };

  return (
    <button onClick={handlePlanClick} className="px-3 py-2 rounded bg-blue-600 text-white">
      Plan Route
    </button>
  );
};

export default PlanButton;
