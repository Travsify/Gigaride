export type UserRole = 'PASSENGER' | 'DRIVER' | 'ADMIN';

export interface RegisterUserDto {
  role: UserRole;
  fullName: string;
  phoneNumber: string;
  email: string;
  password: string;
  // Driver-specific fields
  vehicleMake?: string;
  vehicleModel?: string;
  vehicleYear?: number;
  licensePlate?: string;
  vehicleColor?: string;
  nin?: string;
  bvn?: string;
}

export interface LoginDto {
  identifier: string; // phone or email
  password: string;
}

export type AdminRole = 'SUPER_ADMIN' | 'SUPPORT_AGENT' | 'KYC_OFFICER' | 'FINANCE_ADMIN';

export interface AuthResponse {
  token: string;
  user: {
    id: string;
    role: UserRole;
    adminRole?: AdminRole;
    admin_role?: AdminRole;
    fullName: string;
    phoneNumber: string;
    email: string;
  };
  driverProfile?: any;
}

export interface JwtPayload {
  userId: string;
  role: UserRole;
  adminRole?: AdminRole;
  email: string;
  phoneNumber: string;
}
