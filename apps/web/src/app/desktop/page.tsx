"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { getRoleFromURL } from "@/src/lib/roleFromDesktop";

export default function DesktopEntry() {
  const router = useRouter();
  useEffect(() => {
    const role = getRoleFromURL() ?? "owner-operator";
    router.replace(`/signup/${role}`);
  }, [router]);
  return null;
}
