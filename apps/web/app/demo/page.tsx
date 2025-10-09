import { SupabaseProvider } from "@/contexts/SupabaseContext";
import { PlanButton } from "@/components/PlanButton";
import { ProfileDisplay } from "@/components/ProfileDisplay";

export default function DemoPage() {
  return (
    <SupabaseProvider>
      <div className="container mx-auto p-4">
        <h1 className="text-2xl font-bold mb-4">Route Planning Application</h1>

        <ProfileDisplay />

        <div className="flex space-x-4 mt-6">
          <PlanButton planType="cycling" destination="Golden Gate Bridge" />
          <PlanButton planType="hiking" destination="Muir Woods" />
        </div>
      </div>
    </SupabaseProvider>
  );
}
