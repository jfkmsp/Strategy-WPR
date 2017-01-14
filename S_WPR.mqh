//+------------------------------------------------------------------+
//|                 EA31337 - multi-strategy advanced trading robot. |
//|                       Copyright 2016-2017, 31337 Investments Ltd |
//|                                       https://github.com/EA31337 |
//+------------------------------------------------------------------+

/*
    This file is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

// Properties.
#property strict

/**
 * @file
 * Implementation of WPR Strategy based on the Larry Williams' Percent Range indicator.
 *
 * @docs
 * - https://docs.mql4.com/indicators/iWPR
 * - https://www.mql5.com/en/docs/indicators/iWPR
 */

// Includes.
#include <EA31337-classes\Strategy.mqh>
#include <EA31337-classes\Strategies.mqh>

// User inputs.
#ifdef __input__ input #endif string __WPR_Parameters__ = "-- Settings for the Larry Williams' Percent Range indicator --"; // >>> WPR <<<
#ifdef __input__ input #endif int WPR_Period = 9; // Period
#ifdef __input__ input #endif double WPR_Period_Ratio = 0.2; // Period ratio between timeframes (0.5-1.5)
#ifdef __input__ input #endif int WPR_Shift = -2; // Shift
#ifdef __input__ input #endif int WPR_SignalLevel = -7; // Signal level
#ifdef __input__ input #endif int WPR_SignalMethod = 36; // Signal method for M1 (-63-63)

class WPR: public Strategy {

protected:

  double wpr[H1][FINAL_ENUM_INDICATOR_INDEX];
  int       open_method = EMPTY;    // Open method.
  double    open_level  = 0.0;     // Open level.

    public:

  /**
   * Update indicator values.
   */
  bool Update(int tf = EMPTY) {
    // Calculates the  Larry Williams' Percent Range.
    // Update the Larry Williams' Percent Range indicator values.
    ratio = tf == 30 ? 1.0 : fmax(WPR_Period_Ratio, NEAR_ZERO) / tf * 30;
    for (i = 0; i < FINAL_ENUM_INDICATOR_INDEX; i++) {
      wpr[index][i] = -iWPR(symbol, tf, (int) (WPR_Period * ratio), i + WPR_Shift);
    }
    if (VerboseDebug) PrintFormat("WPR M%d: %s", tf, Arrays::ArrToString2D(wpr, ",", Digits));
    success = (bool) wpr[index][CURR] + wpr[index][PREV] + wpr[index][FAR];
  }

  /**
   * Checks whether signal is on buy or sell.
   *
   * @param
   *   cmd (int) - type of trade order command
   *   period (int) - period to check for
   *   signal_method (int) - signal method to use by using bitwise AND operation
   *   signal_level (double) - signal level to consider the signal
   */
  bool Signal(int cmd, ENUM_TIMEFRAMES tf = PERIOD_M1, int signal_method = EMPTY, double signal_level = EMPTY) {
    bool result = FALSE; int period = Timeframe::TfToIndex(tf);
    UpdateIndicator(S_WPR, tf);
    if (signal_method == EMPTY) signal_method = GetStrategySignalMethod(S_WPR, tf, 0);
    if (signal_level == EMPTY)  signal_level  = GetStrategySignalLevel(S_WPR, tf, 0);

    switch (cmd) {
      case OP_BUY:
        result = wpr[period][CURR] > 50 + signal_level;
        if ((signal_method &   1) != 0) result &= wpr[period][CURR] < wpr[period][PREV];
        if ((signal_method &   2) != 0) result &= wpr[period][PREV] < wpr[period][FAR];
        if ((signal_method &   4) != 0) result &= wpr[period][PREV] > 50 + signal_level;
        if ((signal_method &   8) != 0) result &= wpr[period][FAR]  > 50 + signal_level;
        if ((signal_method &  16) != 0) result &= wpr[period][PREV] - wpr[period][CURR] > wpr[period][FAR] - wpr[period][PREV];
        if ((signal_method &  32) != 0) result &= wpr[period][PREV] > 50 + signal_level + signal_level / 2;
        /* TODO:

              //30. Williams Percent Range
              //Buy: crossing -80 upwards
              //Sell: crossing -20 downwards
              if (iWPR(NULL,piwpr,piwprbar,1)<-80&&iWPR(NULL,piwpr,piwprbar,0)>=-80)
              {f30=1;}
              if (iWPR(NULL,piwpr,piwprbar,1)>-20&&iWPR(NULL,piwpr,piwprbar,0)<=-20)
              {f30=-1;}
        */
        break;
      case OP_SELL:
        result = wpr[period][CURR] < 50 - signal_level;
        if ((signal_method &   1) != 0) result &= wpr[period][CURR] > wpr[period][PREV];
        if ((signal_method &   2) != 0) result &= wpr[period][PREV] > wpr[period][FAR];
        if ((signal_method &   4) != 0) result &= wpr[period][PREV] < 50 - signal_level;
        if ((signal_method &   8) != 0) result &= wpr[period][FAR]  < 50 - signal_level;
        if ((signal_method &  16) != 0) result &= wpr[period][CURR] - wpr[period][PREV] > wpr[period][PREV] - wpr[period][FAR];
        if ((signal_method &  32) != 0) result &= wpr[period][PREV] > 50 - signal_level - signal_level / 2;
        break;
    }
    result &= signal_method <= 0 || Convert::ValueToOp(curr_trend) == cmd;
    if (VerboseTrace && result) {
      PrintFormat("%s:%d: Signal: %d/%d/%d/%g", __FUNCTION__, __LINE__, cmd, tf, signal_method, signal_level);
    }
    return result;
  }
};
