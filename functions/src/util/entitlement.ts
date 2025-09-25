/**
 * Entitlement management utilities
 * Handles user entitlements and subscription logic
 */

export type EntitlementType = 'past' | 'textbooks' | 'both' | 'premium';

export interface EntitlementUpdate {
  userId: string;
  entitlements: EntitlementType[];
  expiresAt?: Date;
  source: 'payment' | 'admin' | 'promotion';
  metadata?: Record<string, any>;
}

/**
 * Update user entitlements
 * @param userId User ID to update
 * @param newEntitlements New entitlements to grant
 * @param expiresAt Optional expiration date
 */
export async function updateEntitlements(
  userId: string, 
  newEntitlements: EntitlementType[], 
  expiresAt?: Date
): Promise<void> {
  // This will be implemented with Firestore operations
  console.log(`Updating entitlements for user ${userId}:`, newEntitlements);
  
  if (expiresAt) {
    console.log(`Entitlements expire at: ${expiresAt}`);
  }
}

/**
 * Check if user has required entitlement
 * @param userEntitlements Current user entitlements
 * @param required Required entitlement
 * @returns Whether user has access
 */
export function hasEntitlement(
  userEntitlements: EntitlementType[], 
  required: EntitlementType
): boolean {
  // Premium includes everything
  if (userEntitlements.includes('premium')) return true;
  
  // Both includes past and textbooks
  if (userEntitlements.includes('both') && (required === 'past' || required === 'textbooks')) {
    return true;
  }
  
  // Direct match
  return userEntitlements.includes(required);
}

/**
 * Get entitlement hierarchy (what each entitlement includes)
 * @param entitlement Base entitlement
 * @returns Array of all included features
 */
export function getIncludedFeatures(entitlement: EntitlementType): string[] {
  switch (entitlement) {
    case 'past':
      return ['past_questions', 'mock_exams', 'progress_tracking'];
    case 'textbooks':
      return ['textbook_access', 'offline_reading', 'bookmarks'];
    case 'both':
      return [
        'past_questions', 'mock_exams', 'progress_tracking',
        'textbook_access', 'offline_reading', 'bookmarks'
      ];
    case 'premium':
      return [
        'past_questions', 'mock_exams', 'progress_tracking',
        'textbook_access', 'offline_reading', 'bookmarks',
        'ai_tutor', 'unlimited_ai_questions', 'priority_support',
        'advanced_analytics', 'custom_study_plans'
      ];
    default:
      return [];
  }
}

/**
 * Calculate subscription value in Ghana Cedis
 * @param plan Subscription plan
 * @param cycle Billing cycle
 * @returns Price in GHS
 */
export function getSubscriptionPrice(
  plan: 'past' | 'textbooks' | 'both' | 'premium',
  cycle: 'weekly' | 'bi_weekly' | 'monthly' | 'yearly'
): number {
  const prices = {
    past: {
      weekly: 2.99,
      bi_weekly: 4.99,
      monthly: 9.99,
      yearly: 109.89
    },
    textbooks: {
      weekly: 2.99,
      bi_weekly: 4.99, 
      monthly: 9.99,
      yearly: 109.89
    },
    both: {
      weekly: 5.49,
      bi_weekly: 9.49,
      monthly: 18.99,
      yearly: 199.99
    },
    premium: {
      weekly: 5.39,
      bi_weekly: 9.39,
      monthly: 19.39,
      yearly: 199.99
    }
  };

  return prices[plan][cycle];
}

/**
 * Check if entitlement is expired
 * @param expiresAt Expiration timestamp
 * @returns Whether entitlement is expired
 */
export function isExpired(expiresAt?: Date): boolean {
  if (!expiresAt) return false;
  return new Date() > expiresAt;
}

/**
 * Get days until expiration
 * @param expiresAt Expiration date
 * @returns Days remaining (negative if expired)
 */
export function getDaysUntilExpiration(expiresAt?: Date): number {
  if (!expiresAt) return Infinity;
  
  const now = new Date();
  const diffMs = expiresAt.getTime() - now.getTime();
  return Math.ceil(diffMs / (1000 * 60 * 60 * 24));
}