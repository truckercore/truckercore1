// Bridge re-export so apps/web can import from "@/hooks/useHazards"
// This forwards to the shared implementation at the monorepo root.
// TODO: Move shared web hooks into a proper shared package or workspace.
export * from "../../../../src/hooks/useHazards";
