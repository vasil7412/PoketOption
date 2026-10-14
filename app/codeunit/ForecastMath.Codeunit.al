codeunit 50114 "SMA Forecast Math"
{
    Access = Internal;

    procedure Sqrt(Value: Decimal): Decimal
    begin
        if Value <= 0 then
            exit(0);
        exit(Power(Value, 0.5));
    end;

    procedure Sign(Value: Decimal): Integer
    begin
        if Value > 0 then
            exit(1);
        if Value < 0 then
            exit(-1);
        exit(0);
    end;

    /// <summary>
    /// Standard deviation of one-candle price changes. Under a random walk the error of an h-step forecast grows as this value * sqrt(h).
    /// </summary>
    procedure ChangeStdDev(Series: List of [Decimal]): Decimal
    var
        Change: Decimal;
        SumChange: Decimal;
        SumSquares: Decimal;
        Mean: Decimal;
        n: Integer;
        i: Integer;
    begin
        n := Series.Count() - 1;
        if n < 2 then
            exit(0);
        for i := 2 to Series.Count() do begin
            Change := Series.Get(i) - Series.Get(i - 1);
            SumChange += Change;
            SumSquares += Change * Change;
        end;
        Mean := SumChange / n;
        exit(Sqrt((SumSquares - n * Mean * Mean) / (n - 1)));
    end;
}
