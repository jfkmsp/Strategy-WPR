//+------------------------------------------------------------------+
//|                  EA31337 - multi-strategy advanced trading robot |
//|                       Copyright 2016-2020, 31337 Investments Ltd |
//|                                       https://github.com/EA31337 |
//+------------------------------------------------------------------+

/**
 * @file
 * Implements WPR strategy based on the Larry Williams' Percent Range indicator.
 */

// Includes.
#include <EA31337-classes/Indicators/Indi_WPR.mqh>
#include <EA31337-classes/Strategy.mqh>

// User input params.
INPUT string __WPR_Parameters__ = "-- WPR strategy params --";  // >>> WPR <<<
INPUT int WPR_Active_Tf = 0;         // Activate timeframes (1-255, e.g. M1=1,M5=2,M15=4,M30=8,H1=16,H2=32...)
INPUT int WPR_Period = 11;           // Period
INPUT int WPR_Shift = 0;             // Shift
INPUT int WPR_SignalOpenLevel = 20;  // Signal open level
INPUT ENUM_TRAIL_TYPE WPR_TrailingStopMethod = 22;    // Trail stop method
INPUT ENUM_TRAIL_TYPE WPR_TrailingProfitMethod = 11;  // Trail profit method
INPUT int WPR1_SignalBaseMethod = -46;                // Signal base method (-63-63)
INPUT int WPR1_OpenCondition1 = 874;                  // Open condition 1 (0-1023)
INPUT int WPR1_OpenCondition2 = 0;                    // Open condition 2 (0-1023)
INPUT ENUM_MARKET_EVENT WPR1_CloseCondition = 1;      // Close condition for M1
INPUT double WPR_MaxSpread = 6.0;                     // Max spread to trade (pips)

// Struct to define strategy parameters to override.
struct Stg_WPR_Params : Stg_Params {
  unsigned int WPR_Period;
  ENUM_APPLIED_PRICE WPR_Applied_Price;
  int WPR_Shift;
  ENUM_TRAIL_TYPE WPR_TrailingStopMethod;
  ENUM_TRAIL_TYPE WPR_TrailingProfitMethod;
  double WPR_SignalOpenLevel;
  long WPR_SignalBaseMethod;
  long WPR_SignalOpenMethod1;
  long WPR_SignalOpenMethod2;
  double WPR_SignalCloseLevel;
  ENUM_MARKET_EVENT WPR_SignalCloseMethod1;
  ENUM_MARKET_EVENT WPR_SignalCloseMethod2;
  double WPR_MaxSpread;

  // Constructor: Set default param values.
  Stg_WPR_Params()
      : WPR_Period(::WPR_Period),
        WPR_Applied_Price(::WPR_Applied_Price),
        WPR_Shift(::WPR_Shift),
        WPR_TrailingStopMethod(::WPR_TrailingStopMethod),
        WPR_TrailingProfitMethod(::WPR_TrailingProfitMethod),
        WPR_SignalOpenLevel(::WPR_SignalOpenLevel),
        WPR_SignalBaseMethod(::WPR_SignalBaseMethod),
        WPR_SignalOpenMethod1(::WPR_SignalOpenMethod1),
        WPR_SignalOpenMethod2(::WPR_SignalOpenMethod2),
        WPR_SignalCloseLevel(::WPR_SignalCloseLevel),
        WPR_SignalCloseMethod1(::WPR_SignalCloseMethod1),
        WPR_SignalCloseMethod2(::WPR_SignalCloseMethod2),
        WPR_MaxSpread(::WPR_MaxSpread) {}
};

// Loads pair specific param values.
#include "sets/EURUSD_H1.h"
#include "sets/EURUSD_H4.h"
#include "sets/EURUSD_M1.h"
#include "sets/EURUSD_M15.h"
#include "sets/EURUSD_M30.h"
#include "sets/EURUSD_M5.h"

class Stg_WPR : public Strategy {
 public:
  Stg_WPR(StgParams &_params, string _name) : Strategy(_params, _name) {}

  static Stg_WPR *Init(ENUM_TIMEFRAMES _tf = NULL, long _magic_no = NULL, ENUM_LOG_LEVEL _log_level = V_INFO) {
    // Initialize strategy initial values.
    Stg_WPR_Params _params;
    switch (_tf) {
      case PERIOD_M1: {
        Stg_WPR_EURUSD_M1_Params _new_params;
        _params = _new_params;
      }
      case PERIOD_M5: {
        Stg_WPR_EURUSD_M5_Params _new_params;
        _params = _new_params;
      }
      case PERIOD_M15: {
        Stg_WPR_EURUSD_M15_Params _new_params;
        _params = _new_params;
      }
      case PERIOD_M30: {
        Stg_WPR_EURUSD_M30_Params _new_params;
        _params = _new_params;
      }
      case PERIOD_H1: {
        Stg_WPR_EURUSD_H1_Params _new_params;
        _params = _new_params;
      }
      case PERIOD_H4: {
        Stg_WPR_EURUSD_H4_Params _new_params;
        _params = _new_params;
      }
    }
    // Initialize strategy parameters.
    ChartParams cparams(_tf);
    WPR_Params adx_params(_params.WPR_Period, _params.WPR_Applied_Price);
    IndicatorParams adx_iparams(10, INDI_WPR);
    StgParams sparams(new Trade(_tf, _Symbol), new Indi_WPR(adx_params, adx_iparams, cparams), NULL, NULL);
    sparams.logger.SetLevel(_log_level);
    sparams.SetMagicNo(_magic_no);
    sparams.SetSignals(_params.WPR_SignalBaseMethod, _params.WPR_SignalOpenMethod1, _params.WPR_SignalOpenMethod2,
                       _params.WPR_SignalCloseMethod1, _params.WPR_SignalCloseMethod2, _params.WPR_SignalOpenLevel,
                       _params.WPR_SignalCloseLevel);
    sparams.SetStops(_params.WPR_TrailingProfitMethod, _params.WPR_TrailingStopMethod);
    sparams.SetMaxSpread(_params.WPR_MaxSpread);
    // Initialize strategy instance.
    Strategy *_strat = new Stg_WPR(sparams, "WPR");
    return _strat;
  }

  /**
   * Check if WPR indicator is on buy or sell.
   *
   * @param
   *   _cmd (int) - type of trade order command
   *   period (int) - period to check for
   *   _signal_method (int) - signal method to use by using bitwise AND operation
   *   _signal_level1 (double) - signal level to consider the signal
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, long _signal_method = EMPTY, double _signal_level = EMPTY) {
    bool _result = false;
    double wpr_0 = ((Indi_WPR *)this.Data()).GetValue(0);
    double wpr_1 = ((Indi_WPR *)this.Data()).GetValue(1);
    double wpr_2 = ((Indi_WPR *)this.Data()).GetValue(2);
    if (_signal_method == EMPTY) _signal_method = GetSignalBaseMethod();
    if (_signal_level1 == EMPTY) _signal_level1 = GetSignalLevel1();
    if (_signal_level2 == EMPTY) _signal_level2 = GetSignalLevel2();

    switch (_cmd) {
      case ORDER_TYPE_BUY:
        _result = wpr_0 > 50 + _signal_level1;
        if (_signal_method != 0) {
          if (METHOD(_signal_method, 0)) _result &= wpr_0 < wpr_1;
          if (METHOD(_signal_method, 1)) _result &= wpr_1 < wpr_2;
          if (METHOD(_signal_method, 2)) _result &= wpr_1 > 50 + _signal_level1;
          if (METHOD(_signal_method, 3)) _result &= wpr_2 > 50 + _signal_level1;
          if (METHOD(_signal_method, 4)) _result &= wpr_1 - wpr_0 > wpr_2 - wpr_1;
          if (METHOD(_signal_method, 5)) _result &= wpr_1 > 50 + _signal_level1 + _signal_level1 / 2;
        }
        /* @todo
           //30. Williams Percent Range
           //Buy: crossing -80 upwards
           //Sell: crossing -20 downwards
           if (iWPR(NULL,piwpr,piwprbar,1)<-80&&iWPR(NULL,piwpr,piwprbar,0)>=-80)
           {f30=1;}
           if (iWPR(NULL,piwpr,piwprbar,1)>-20&&iWPR(NULL,piwpr,piwprbar,0)<=-20)
           {f30=-1;}
        */
        break;
      case ORDER_TYPE_SELL:
        _result = wpr_0 < 50 - _signal_level1;
        if (_signal_method != 0) {
          if (METHOD(_signal_method, 0)) _result &= wpr_0 > wpr_1;
          if (METHOD(_signal_method, 1)) _result &= wpr_1 > wpr_2;
          if (METHOD(_signal_method, 2)) _result &= wpr_1 < 50 - _signal_level1;
          if (METHOD(_signal_method, 3)) _result &= wpr_2 < 50 - _signal_level1;
          if (METHOD(_signal_method, 4)) _result &= wpr_0 - wpr_1 > wpr_1 - wpr_2;
          if (METHOD(_signal_method, 5)) _result &= wpr_1 > 50 - _signal_level1 - _signal_level1 / 2;
        }
        break;
    }
    return _result;
  }

  /**
   * Check strategy's closing signal.
   */
  bool SignalClose(ENUM_ORDER_TYPE _cmd, long _signal_method = EMPTY, double _signal_level = EMPTY) {
    if (_signal_level == EMPTY) _signal_level = GetSignalCloseLevel();
    return SignalOpen(Order::NegateOrderType(_cmd), _signal_method, _signal_level);
  }
};
