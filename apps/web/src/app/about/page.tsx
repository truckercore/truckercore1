// TypeScript
"use client";
import React from "react";
import { AboutUpdatesPanel } from "@/components/AboutUpdatesPanel";

export default function AboutPage() {
  const appVersion = process.env.NEXT_PUBLIC_SHELL_VERSION || "";
  const webBuild = process.env.NEXT_PUBLIC_BUILD_SHA || "";
  return (
    <div style={{ padding: 24 }}>
      <AboutUpdatesPanel appVersion={appVersion} webBuild={webBuild} />
    </div>
  );
}
