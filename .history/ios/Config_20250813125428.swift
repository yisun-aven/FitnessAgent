import Foundation

enum AppConfig {
    static let supabaseURL = URL(string: "https://tqbtufjwjcsgnhoopiyx.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRxYnR1Zmp3amNzZ25ob29waXl4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUxMTI3NDIsImV4cCI6MjA3MDY4ODc0Mn0.O4TBHzEKAfOJ_Kj_O3cSE95URlTpAk7lLYIpITnXlAo"
    static let backendBaseURL = URL(string: "http://127.0.0.1:8000")! // For Simulator
}
