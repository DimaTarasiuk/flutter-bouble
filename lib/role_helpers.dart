/// Gate робиться по role, НЕ по хардкодженому логіну (див. API_SPEC §head).
bool isHeadRole(String? role) => role == 'head';
bool isStaffRole(String? role) => role == 'head' || role == 'admin';
