/// <summary>
/// Stochastic oscillator rule on high/low prices: %K at or below the oversold level and turning above %D predicts a move up,
/// %K at or above the overbought level and turning below %D predicts a move down, otherwise no signal.
/// </summary>
codeunit 50122 "SMA Stochastic Fcst" implements "SMA IForecast Method"
{
    Access = Internal;

    var
        ForecastMath: Codeunit "SMA Forecast Math";

    procedure Forecast(var ForecastContext: Codeunit "SMA Forecast Context"; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal])
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        Series: List of [Decimal];
        HighestHigh: Decimal;
        LowestLow: Decimal;
        KValue: Decimal;
        LastK: Decimal;
        SumK: Decimal;
        DValue: Decimal;
        Oversold: Decimal;
        Overbought: Decimal;
        Fraction: Decimal;
        Direction: Integer;
        Period: Integer;
        Smoothing: Integer;
        CurrentPosition: Integer;
        k: Integer;
        i: Integer;
    begin
        Clear(Points);
        Clear(Sigmas);
        ForecastContext.GetSetup(RateAnalyzerSetup);
        Period := RateAnalyzerSetup.GetStochasticPeriod();
        Smoothing := RateAnalyzerSetup.GetStochasticSmoothing();
        RateAnalyzerSetup.GetStochasticLevels(Oversold, Overbought);
        CurrentPosition := ForecastContext.Position();
        if CurrentPosition - Period - Smoothing + 2 < ForecastContext.WindowStart() then
            exit;
        Series := ForecastContext.WindowCloses();
        if Series.Count() < 3 then
            exit;

        for k := CurrentPosition - Smoothing + 1 to CurrentPosition do begin
            HighestHigh := ForecastContext.HighAt(k);
            LowestLow := ForecastContext.LowAt(k);
            for i := k - Period + 1 to k - 1 do begin
                if ForecastContext.HighAt(i) > HighestHigh then
                    HighestHigh := ForecastContext.HighAt(i);
                if ForecastContext.LowAt(i) < LowestLow then
                    LowestLow := ForecastContext.LowAt(i);
            end;
            KValue := 50;
            if HighestHigh > LowestLow then
                KValue := (ForecastContext.CloseAt(k) - LowestLow) / (HighestHigh - LowestLow) * 100;
            SumK += KValue;
            LastK := KValue;
        end;
        DValue := SumK / Smoothing;

        if (LastK <= Oversold) and (LastK > DValue) then begin
            Direction := 1;
            Fraction := (Oversold - LastK) / Oversold;
        end;
        if (LastK >= Overbought) and (LastK < DValue) then begin
            Direction := -1;
            Fraction := (LastK - Overbought) / (100 - Overbought);
        end;
        ForecastMath.IndicatorForecast(ForecastContext.CloseAt(CurrentPosition), Direction, Fraction, ForecastMath.ChangeStdDev(Series), Steps, Points, Sigmas);
    end;
}
