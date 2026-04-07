import { useRoadDoggEvent } from "@/lib/roaddogg/useRoadDoggEvent";

export function PlanButton(props: {
  orgId: string;
  origin_zip: string;
  dest_zip: string;
  deadhead_miles?: number;
  tolls?: boolean;
  pickup_time_local?: string; // ISO string
}) {
  const { track } = useRoadDoggEvent(props.orgId);

  async function onPlan() {
    await track("route_planned", {
      origin_zip: props.origin_zip,
      dest_zip: props.dest_zip,
      deadhead_miles: props.deadhead_miles ?? null,
      tolls: !!props.tolls,
      pickup_time_local: props.pickup_time_local ?? null,
    });
  }

  return (
    <button onClick={onPlan} className="px-3 py-2 rounded bg-blue-600 text-white">
      Plan Route
    </button>
  );
}
