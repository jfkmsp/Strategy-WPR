//+------------------------------------------------------------------+
//|                  EA31337 - multi-strategy advanced trading robot |
//|                       Copyright 2016-2020, 31337 Investments Ltd |
//|                                       https://github.com/EA31337 |
//+------------------------------------------------------------------+

// Defines strategy's parameter values for the given pair symbol and timeframe.
struct Stg_WPR_EURUSD_M1_Params : Stg_WPR_Params {
  Stg_WPR_EURUSD_M1_Params() {
    symbol = "EURUSD";
    tf = PERIOD_M1;
    WPR_Period = 32;
    WPR_Applied_Price = 3;
    WPR_Shift = 0;
    WPR_TrailingStopMethod = 6;
    WPR_TrailingProfitMethod = 11;
    WPR_SignalOpenLevel = 36;
    WPR_SignalBaseMethod = 0;
    WPR_SignalOpenMethod1 = 0;
    WPR_SignalOpenMethod2 = 0;
    WPR_SignalCloseLevel = 36;
    WPR_SignalCloseMethod1 = 0;
    WPR_SignalCloseMethod2 = 0;
    WPR_MaxSpread = 2;
  }
};