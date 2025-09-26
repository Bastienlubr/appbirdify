// Garde-fous IAP/Premium
// - kPremiumSecureFlow: active le flux sécurisé (CF prioritaire)
// - kEnableClientFallback: autorise le fallback d'écriture Firestore côté client (sandbox/tests)

const bool kPremiumSecureFlow = true;

// Active via: --dart-define=IAP_SANDBOX_FALLBACK=true
const bool kEnableClientFallback = bool.fromEnvironment(
  'IAP_SANDBOX_FALLBACK',
  defaultValue: false,
);


