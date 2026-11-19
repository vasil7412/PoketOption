/// <summary>
/// Relative Strength Index rule (Wilder smoothing): RSI at or below the oversold level predicts a move up,
/// at or above the overbought level a move down, otherwise no signal. The further beyond the level, the larger the predicted move.
/// </summary>
codeunit 50121 "SMA RSI Fcst" implements "SMA IForecast Method"
{
    Access = Internal;

    var
        ForecastMath: Codeunit "SMA Forecast Math";

    procedure Forecast(var ForecastContext: Codeunit "SMA Forecast Context"; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal])
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        Series: List of [Decimal];
        Change: Decimal;
        AvgGain: Decimal;
        AvgLoss: Decimal;
        RSI: Decimal;
        Oversold: Decimal;
        Overbought: Decimal;
        Fraction: Decimal;
        Direction: Integer;
        Period: Integer;
        n: Integer;
        t: Integer;
    begin
        Clear(Points);
        Clear(Sigmas);
        ForecastContext.GetSetup(RateAnalyzerSetup);
        Period := RateAnalyzerSetup.GetRSIPeriod();
        RateAnalyzerSetup.GetRSILevels(Oversold, Overbought);
        Series := ForecastContext.WindowCloses();
        n := Series.Count();
        if n < Period + 2 then
            exit;

        for t := 2 to Period + 1 do begin
            Change := Series.Get(t) - Series.Get(t - 1);
            if Change > 0 then
                AvgGain += Change
            else
                AvgLoss -= Change;
        end;
        AvgGain := AvgGain / Period;
        AvgLoss := AvgLoss / Period;
        for t := Period + 2 to n do begin
            Change := Series.Get(t) - Series.Get(t - 1);
            if Change > 0 then begin
                AvgGain := (AvgGain * (Period - 1) + Change) / Period;
                AvgLoss := AvgLoss * (Period - 1) / Period;
            end else begin
                AvgGain := AvgGain * (Period - 1) / Period;
                AvgLoss := (AvgLoss * (Period - 1) - Change) / Period;
            end;
        end;

        case true of
            (AvgGain = 0) and (AvgLoss = 0):
                RSI := 50;
            AvgLoss = 0:
                RSI := 100;
            else
                RSI := 100 - 100 / (1 + AvgGain / AvgLoss);
        end;

        if RSI <= Oversold then begin
            Direction := 1;
            Fraction := (Oversold - RSI) / Oversold;
        end;
        if RSI >= Overbought then begin
            Direction := -1;
            Fraction := (RSI - Overbought) / (100 - Overbought);
        end;
        ForecastMath.IndicatorForecast(Series.Get(n), Direction, Fraction, ForecastMath.ChangeStdDev(Series), Steps, Points, Sigmas);
    end;
}
