function Komorebi-Toggle {
    if (Get-Process komorebi -ErrorAction SilentlyContinue) {
        komorebic stop --whkd --bar --masir
    }
    else {
        komorebic start --whkd --bar --masir
    }
}
