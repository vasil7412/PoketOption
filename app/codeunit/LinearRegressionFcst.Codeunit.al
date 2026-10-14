/// <summary>
/// Fits a straight line to the series by least squares and extends it into the future.
/// </summary>
codeunit 50105 "SMA Linear Regression Fcst" implements "SMA IForecast Method"
{
    Access = Internal;

    var
        ForecastMath: Codeunit "SMA Forecast Math";

    procedure Forecast(Series: List of [Decimal]; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal])
    var
        SumX: Decimal;
        SumY: Decimal;
        SumXX: Decimal;
        SumXY: Decimal;
        Denominator: Decimal;
        Slope: Decimal;
        Intercept: Decimal;
        StepSigma: Decimal;
        x: Decimal;
        y: Decimal;
        n: Integer;
        i: Integer;
        Step: Integer;
    begin
        Clear(Points);
        Clear(Sigmas);
        n := Series.Count();
        if n = 0 then
            exit;

        for i := 1 to n do begin
            x := i - 1;
            y := Series.Get(i);
            SumX += x;
            SumY += y;
            SumXX += x * x;
            SumXY += x * y;
        end;

        Denominator := n * SumXX - SumX * SumX;
        if Denominator <> 0 then
            Slope := (n * SumXY - SumX * SumY) / Denominator;
        Intercept := (SumY - Slope * SumX) / n;
        StepSigma := ForecastMath.ChangeStdDev(Series);

        for Step := 1 to Steps do begin
            Points.Add(Intercept + Slope * (n - 1 + Step));
            Sigmas.Add(StepSigma * ForecastMath.Sqrt(Step));
        end;
    end;
}
