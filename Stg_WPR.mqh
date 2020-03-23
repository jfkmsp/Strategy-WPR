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
INPUT int WPR_Period = 14;                                      // Period
INPUT int WPR_Shift = 0;                                        // Shift
INPUT int WPR_SignalOpenMethod = 0;                             // Signal open method (-63-63)
INPUT double WPR_SignalOpenLevel = 0;                           // Signal open level
INPUT int WPR_SignalOpenFilterMethod = 0;                       // Signal open filter method
INPUT int WPR_SignalOpenBoostMethod = 0;                        // Signal open boost method
INPUT int WPR_SignalCloseMethod = 0;                            // Signal close method (-63-63)
INPUT int WPR_SignalCloseLevel = 0;                             // Signal close level
INPUT int WPR_PriceLimitMethod = 0;                             // Price limit method
INPUT double WPR_PriceLimitLevel = 0;                           // Price limit level
INPUT double WPR_MaxSpread = 6.0;                               // Max spread to trade (pips)

// Struct to define strategy parameters to override.
struct Stg_WPR_Params : StgParams {
  unsigned int WPR_Period;
  int WPR_Shift;
  int WPR_SignalOpenMethod;
  double WPR_SignalOpenLevel;
  int WPR_SignalOpenFilterMethod;
  int WPR_SignalOpenBoostMethod;
  int WPR_SignalCloseMethod;
  double WPR_SignalCloseLevel;
  int WPR_PriceLimitMethod;
  double WPR_PriceLimitLevel;
  double WPR_MaxSpread;

  // Constructor: Set default param values.
  Stg_WPR_Params()
      : WPR_Period(::WPR_Period),
        WPR_Shift(::WPR_Shift),
        WPR_SignalOpenMethod(::WPR_SignalOpenMethod),
        WPR_SignalOpenLevel(::WPR_SignalOpenLevel),
        WPR_SignalOpenFilterMethod(::WPR_SignalOpenFilterMethod),
        WPR_SignalOpenBoostMethod(::WPR_SignalOpenBoostMethod),
        WPR_SignalCloseMethod(::WPR_SignalCloseMethod),
        WPR_SignalCloseLevel(::WPR_SignalCloseLevel),
        WPR_PriceLimitMethod(::WPR_PriceLimitMethod),
        WPR_PriceLimitLevel(::WPR_PriceLimitLevel),
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
    if (!Terminal::IsOptimization()) {
      SetParamsByTf<Stg_WPR_Params>(_params, _tf, stg_wpr_m1, stg_wpr_m5, stg_wpr_m15, stg_wpr_m30, stg_wpr_h1,
                                    stg_wpr_h4, stg_wpr_h4);
    }
    // Initialize strategy parameters.
    WPRParams wpr_params(_params.WPR_Period);
    wpr_params.SetTf(_tf);
    StgParams sparams(new Trade(_tf, _Symbol), new Indi_WPR(wpr_params), NULL, NULL);
    sparams.logger.SetLevel(_log_level);
    sparams.SetMagicNo(_magic_no);
    sparams.SetSignals(_params.WPR_SignalOpenMethod, _params.WPR_SignalOpenLevel, _params.WPR_SignalCloseMethod,
                       _params.WPR_SignalOpenFilterMethod, _params.WPR_SignalOpenBoostMethod,
                       _params.WPR_SignalCloseLevel);
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
   *   _method (int) - signal method to use by using bitwise AND operation
   *   _level (double) - signal level to consider the signal
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method = 0, double _level = 0.0) {
    Indicator *_indi = Data();
    bool _is_valid = _indi[CURR].IsValid() && _indi[PREV].IsValid() && _indi[PPREV].IsValid();
    bool _result = _is_valid;
    if (_is_valid) {
      double level = -50 - _level * Order::OrderDirection(_cmd);
      switch (_cmd) {
        case ORDER_TYPE_BUY:
          // Buy: Value below level.
          _result = _indi[CURR].value[0] < level;
          if (_method != 0) {
            if (METHOD(_method, 0)) _result &= _indi[CURR].value[0] < _indi[PREV].value[0];
            if (METHOD(_method, 1)) _result &= _indi[PREV].value[0] < _indi[PPREV].value[0];
            // Buy: crossing level upwards.
            if (METHOD(_method, 2)) _result &= _indi[PREV].value[0] > level;
            // Buy: crossing level upwards.
            if (METHOD(_method, 3)) _result &= _indi[PPREV].value[0] > level;
            if (METHOD(_method, 4)) _result &= _indi[PREV].value[0] - _indi[CURR].value[0] > _indi[PPREV].value[0] - _indi[PREV].value[0];
            if (METHOD(_method, 5)) _result &= _indi[PREV].value[0] > level + _level / 2;
          }
          /* @todo
             //30. Williams Percent Range
             if (iWPR(NULL,piwpr,piwprbar,1)<-80&&iWPR(NULL,piwpr,piwprbar,0)>=-80)
             {f30=1;}
             if (iWPR(NULL,piwpr,piwprbar,1)>-20&&iWPR(NULL,piwpr,piwprbar,0)<=-20)
             {f30=-1;}
          */
          break;
        case ORDER_TYPE_SELL:
          // Sell: Value above level.
          _result = _indi[CURR].value[0] > level;
          if (_method != 0) {
            if (METHOD(_method, 0)) _result &= _indi[CURR].value[0] > _indi[PREV].value[0];
            if (METHOD(_method, 1)) _result &= _indi[PREV].value[0] > _indi[PPREV].value[0];
            // Sell: crossing level downwards.
            if (METHOD(_method, 2)) _result &= _indi[PREV].value[0] < level;
            // Sell: crossing level downwards.
            if (METHOD(_method, 3)) _result &= _indi[PPREV].value[0] < level;
            if (METHOD(_method, 4)) _result &= _indi[CURR].value[0] - _indi[PREV].value[0] > _indi[PREV].value[0] - _indi[PPREV].value[0];
            if (METHOD(_method, 5)) _result &= _indi[PREV].value[0] > level - _level / 2;
          }
          break;
      }
    }
    return _result;
  }

  /**
   * Check strategy's opening signal additional filter.
   */
  bool SignalOpenFilter(ENUM_ORDER_TYPE _cmd, int _method = 0) {
    bool _result = true;
    if (_method != 0) {
      // if (METHOD(_method, 0)) _result &= Trade().IsTrend(_cmd);
      // if (METHOD(_method, 1)) _result &= Trade().IsPivot(_cmd);
      // if (METHOD(_method, 2)) _result &= Trade().IsPeakHours(_cmd);
      // if (METHOD(_method, 3)) _result &= Trade().IsRoundNumber(_cmd);
      // if (METHOD(_method, 4)) _result &= Trade().IsHedging(_cmd);
      // if (METHOD(_method, 5)) _result &= Trade().IsPeakBar(_cmd);
    }
    return _result;
  }

  /**
   * Gets strategy's lot size boost (when enabled).
   */
  double SignalOpenBoost(ENUM_ORDER_TYPE _cmd, int _method = 0) {
    bool _result = 1.0;
    if (_method != 0) {
      // if (METHOD(_method, 0)) if (Trade().IsTrend(_cmd)) _result *= 1.1;
      // if (METHOD(_method, 1)) if (Trade().IsPivot(_cmd)) _result *= 1.1;
      // if (METHOD(_method, 2)) if (Trade().IsPeakHours(_cmd)) _result *= 1.1;
      // if (METHOD(_method, 3)) if (Trade().IsRoundNumber(_cmd)) _result *= 1.1;
      // if (METHOD(_method, 4)) if (Trade().IsHedging(_cmd)) _result *= 1.1;
      // if (METHOD(_method, 5)) if (Trade().IsPeakBar(_cmd)) _result *= 1.1;
    }
    return _result;
  }

  /**
   * Check strategy's closing signal.
   */
  bool SignalClose(ENUM_ORDER_TYPE _cmd, int _method = 0, double _level = 0.0) {
    return SignalOpen(Order::NegateOrderType(_cmd), _method, _level);
  }

  /**
   * Gets price limit value for profit take or stop loss.
   */
  double PriceLimit(ENUM_ORDER_TYPE _cmd, ENUM_ORDER_TYPE_VALUE _mode, int _method = 0, double _level = 0.0) {
    double _trail = _level * Market().GetPipSize();
    int _direction = Order::OrderDirection(_cmd, _mode);
    double _default_value = Market().GetCloseOffer(_cmd) + _trail * _method * _direction;
    double _result = _default_value;
    switch (_method) {
      case 0:
        // @todo
        break;
    }
    return _result;
  }
};
