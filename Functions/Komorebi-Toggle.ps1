function Komorebi-Toggle {
    if (Get-Process komorebi -ErrorAction SilentlyContinue) {
        komorebic stop --whkd
    }
    else {
        komorebic start --whkd
    }
}
