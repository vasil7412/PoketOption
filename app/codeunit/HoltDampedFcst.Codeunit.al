/// <summary>
/// Holt double exponential smoothing with a damped trend.
/// Level and trend are updated on every candle; the trend fades out in the forecast by the damping factor.
/// </summary>
codeunit 50106 "SMA Holt Damped Fcst" implements "SMA IForecast Method"
{
    Access = Internal;

    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        ForecastMath: Codeunit "SMA Forecast Math";

    procedure Forecast(Series: List of [Decimal]; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal])
    var
        Alpha: Decimal;
        Beta: Decimal;
        Phi: Decimal;
        Level: Decimal;
        PrevLevel: Decimal;
        Trend: Decimal;
        OneStepForecast: Decimal;
        ForecastError: Decimal;
        SumSquaredErrors: Decimal;
        OneStepSigma: Decimal;
        PhiPower: Decimal;
        PhiSum: Decimal;
        n: Integer;
        i: Integer;
        Step: Integer;
    begin
        Clear(Points);
        Clear(Sigmas);
        n := Series.Count();
        if n = 0 then
            exit;

        RateAnalyzerSetup.GetRecordOnce();
        Alpha := RateAnalyzerSetup."Holt Alpha";
        Beta := RateAnalyzerSetup."Holt Beta";
        Phi := RateAnalyzerSetup."Holt Damping";

        Level := Series.Get(1);
        if n > 1 then
            Trend := Series.Get(2) - Series.Get(1);

        for i := 2 to n do begin
            OneStepForecast := Level + Phi * Trend;
            ForecastError := Series.Get(i) - OneStepForecast;
            SumSquaredErrors += ForecastError * ForecastError;
            PrevLevel := Level;
            Level := Alpha * Series.Get(i) + (1 - Alpha) * OneStepForecast;
            Trend := Beta * (Level - PrevLevel) + (1 - Beta) * Phi * Trend;
        end;
        if n > 1 then
            OneStepSigma := ForecastMath.Sqrt(SumSquaredErrors / (n - 1));

        PhiPower := 1;
        for Step := 1 to Steps do begin
            PhiPower := PhiPower * Phi;
            PhiSum += PhiPower;
            Points.Add(Level + PhiSum * Trend);
            Sigmas.Add(OneStepSigma * ForecastMath.Sqrt(Step));
        end;
    end;
}
