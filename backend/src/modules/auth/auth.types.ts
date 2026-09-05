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

export interface AuthResponse {
  token: string;
  user: {
    id: string;
    role: UserRole;
    fullName: string;
    phoneNumber: string;
    email: string;
  };
  driverProfile?: any;
}

export interface JwtPayload {
  userId: string;
  role: UserRole;
  email: string;
  phoneNumber: string;
}
