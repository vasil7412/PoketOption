enum 50100 "SMA Rate Data Provider" implements "SMA IRate Data Provider"
{
    Extensible = true;

    value(0; "Twelve Data")
    {
        Caption = 'Twelve Data';
        Implementation = "SMA IRate Data Provider" = "SMA Twelve Data Provider";
    }
    value(1; OANDA)
    {
        Caption = 'OANDA';
        Implementation = "SMA IRate Data Provider" = "SMA OANDA Provider";
    }
    value(2; Binance)
    {
        Caption = 'Binance';
        Implementation = "SMA IRate Data Provider" = "SMA Binance Provider";
    }
    value(3; Biquote)
    {
        Caption = 'Biquote';
        Implementation = "SMA IRate Data Provider" = "SMA Biquote Provider";
    }
}
