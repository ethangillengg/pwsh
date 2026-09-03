function Komorebi-Toggle {
    if (Get-Process komorebi -ErrorAction SilentlyContinue) {
        komorebic stop --whkd --masir
    }
    else {
        komorebic start --whkd --masir
    }
}
