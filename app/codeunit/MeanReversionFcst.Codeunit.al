/// <summary>
/// Mean reversion: if the price is more than the threshold of standard deviations away from its moving average,
/// predicts that the deviation decays geometrically (Ornstein-Uhlenbeck); otherwise gives no signal (flat forecast).
/// The decay speed is estimated as the AR(1) coefficient of the deviations over the period.
/// </summary>
codeunit 50120 "SMA Mean Reversion Fcst" implements "SMA IForecast Method"
{
    Access = Internal;

    var
        ForecastMath: Codeunit "SMA Forecast Math";

    procedure Forecast(var ForecastContext: Codeunit "SMA Forecast Context"; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal])
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        Series: List of [Decimal];
        Average: Decimal;
        LevelStdDev: Decimal;
        StepSigma: Decimal;
        Price: Decimal;
        Deviation: Decimal;
        PrevDeviation: Decimal;
        SumXY: Decimal;
        SumXX: Decimal;
        Speed: Decimal;
        Factor: Decimal;
        Threshold: Decimal;
        Reverting: Boolean;
        Period: Integer;
        n: Integer;
        t: Integer;
        Step: Integer;
    begin
        Clear(Points);
        Clear(Sigmas);
        ForecastContext.GetSetup(RateAnalyzerSetup);
        Period := RateAnalyzerSetup.GetMeanReversionPeriod();
        Threshold := RateAnalyzerSetup.GetMeanReversionZ();
        Series := ForecastContext.WindowCloses();
        n := Series.Count();
        if n < Period + 2 then
            exit;

        Price := Series.Get(n);
        Average := ForecastMath.Mean(Series, n - Period + 1, n);
        LevelStdDev := ForecastMath.StdDev(Series, n - Period + 1, n);
        StepSigma := ForecastMath.ChangeStdDev(Series);
        if LevelStdDev > 0 then
            Reverting := Abs(Price - Average) / LevelStdDev >= Threshold;

        Speed := 0.9;
        if Reverting then begin
            for t := n - Period + 2 to n do begin
                PrevDeviation := Series.Get(t - 1) - Average;
                Deviation := Series.Get(t) - Average;
                SumXY += PrevDeviation * Deviation;
                SumXX += PrevDeviation * PrevDeviation;
            end;
            if SumXX > 0 then
                Speed := SumXY / SumXX;
            if Speed < 0.5 then
                Speed := 0.5;
            if Speed > 0.99 then
                Speed := 0.99;
        end;

        Factor := 1;
        for Step := 1 to Steps do begin
            if Reverting then begin
                Factor := Factor * Speed;
                Points.Add(Average + (Price - Average) * Factor);
            end else
                Points.Add(Price);
            Sigmas.Add(StepSigma * ForecastMath.Sqrt(Step));
        end;
    end;
}
