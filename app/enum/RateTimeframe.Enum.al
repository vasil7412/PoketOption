/// <summary>
/// Candle timeframe. The value ordinal is the timeframe length in seconds.
/// </summary>
enum 50101 "SMA Rate Timeframe"
{
    Extensible = false;

    value(15; "15 Sec")
    {
        Caption = '15 sec';
    }
    value(30; "30 Sec")
    {
        Caption = '30 sec';
    }
    value(60; "1 Min")
    {
        Caption = '1 min';
    }
    value(300; "5 Min")
    {
        Caption = '5 min';
    }
}
