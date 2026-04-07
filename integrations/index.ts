// integrations/index.ts
import type { OAuthProvider } from "./core/types";
import { SamsaraProvider } from "./samsara/client";
import { QBOProvider } from "./qbo/client";

export const Providers: Record<string, OAuthProvider> = {
  samsara: SamsaraProvider,
  qbo: QBOProvider,
};
