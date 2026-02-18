graph TB
    subgraph AuthLayer["Authentication"]
        AuthGate[AuthenticationGate]
        ROL[RegisterOrLogin]
        AuthS[AuthService]
    end

    AuthGate -->|User logged in| Home[HomeScreen]
    AuthGate -->|User not logged in| ROL
    ROL -->|Sign in / Sign up| AuthS
    AuthS -->|Updates auth state| AuthGate