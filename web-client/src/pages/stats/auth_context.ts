import { createContext } from "react";

export interface AuthContextData {
	pillminder: string;
	token: string;
}

export const AuthContext = createContext<AuthContextData | null>(null);
