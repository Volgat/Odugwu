//+------------------------------------------------------------------+
//|                                               Odgwu_TargetX2.mq5 |
//|                                  Copyright 2024, HBT. |
//|                                             https://www.Volgat.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "price_action_EA"

// Input parameters
input double LearningRate = 0.1; // Learning rate for the Q-learning algorithm
input double DiscountFactor = 0.95; // Discount factor for future rewards
input double InitialEpsilon = 1.0; // Initial exploration rate for the ε-greedy algorithm
input double MinimumEpsilon = 0.1; // Minimum exploration rate for the ε-greedy algorithm
input double EpsilonDecayRate = 0.01; // Decay rate for the exploration rate
input double lotSize = 0.1; // Lot size for trading

// Global variables
double QTable[2][2][2]; // Q-table for storing Q-values
int CurrentState; // Current state of the environment
int CurrentAction; // Current action taken by the agent
double CurrentReward; // Current reward received by the agent
int OpenPositionType = -1; // Type of open positions: -1 (none), 0 (buy), 1 (sell)
double InitialBalance; // Initial balance of the account

// Function to initialize the Q-table
void InitializeQTable()
{
   for (int s = 0; s < 2; s++)
   {
      for (int i = 0; i < 2; i++)
      {
         for (int j = 0; j < 2; j++)
         {
            QTable[s][i][j] = 0.0;
         }
      }
   }
}

// Function to choose an action based on the ε-greedy algorithm
int ChooseAction()
{
   double RandomNumber = MathRand() / 32767.0;

   if (RandomNumber < InitialEpsilon)
   {
      // Explore randomly
      return MathRand() % 2;
   }
   else
   {
      // Exploit the Q-table
      double MaxQValue = -1.0;
      int ChosenAction = -1;

      for (int i = 0; i < 2; i++)
      {
         if (QTable[CurrentState][i][0] > MaxQValue)
         {
            MaxQValue = QTable[CurrentState][i][0];
            ChosenAction = i;
         }
      }

      return ChosenAction;
   }
}

// Function to update the Q-table using the Q-learning algorithm
void UpdateQTable(int PreviousState, int PreviousAction, double Reward, int NewState)
{
   double MaxQValue = -1.0;
   int MaxQAction = -1;

   for (int i = 0; i < 2; i++)
   {
      if (QTable[NewState][i][0] > MaxQValue)
      {
         MaxQValue = QTable[NewState][i][0];
         MaxQAction = i;
      }
   }

   double NewQValue = Reward + DiscountFactor * MaxQValue;
   QTable[PreviousState][PreviousAction][0] += LearningRate * (NewQValue - QTable[PreviousState][PreviousAction][0]);
}

// Function to determine the state based on the historical data
int DetermineState(string symbol, ENUM_TIMEFRAMES period, int shift)
{
   double PreviousPrice = iClose(symbol, period, shift+1);
   double CurrentPrice = iClose(symbol, period, shift);

   // If the current price is higher than the previous price, the state is bullish (0)
   // If the current price is lower than the previous price, the state is bearish (1)
   return CurrentPrice > PreviousPrice ? 0 : 1;
}

// Function to determine the reward based on the action taken
double DetermineReward(int Action, string symbol, ENUM_TIMEFRAMES period, int shift)
{
   double PreviousPrice = iClose(symbol, period, shift+1);
   double CurrentPrice = iClose(symbol, period, shift);

   // If we bought (action 0) and the price went up, or if we sold (action 1) and the price went down, the reward is the price difference
   // Otherwise, the penalty is the price difference
   if ((Action == 0 && CurrentPrice > PreviousPrice) || (Action == 1 && CurrentPrice < PreviousPrice))
   {
      return MathAbs(CurrentPrice - PreviousPrice); // The reward is the price difference
   }
   else
   {
      return -MathAbs(CurrentPrice - PreviousPrice); // The penalty is the price difference
   }
}

// Function to check if there are any open positions
bool IsAnyOpenPosition()
{
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      count++;
      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         OpenPositionType = 0;
      }
      else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
         OpenPositionType = 1;
      }
   }
   return count >= 5; // Check for a minimum of 5 open positions
}

// Function to execute a buy order
void Buy(string symbol, double lotSize)
{
   // Check if there are less than 5 open positions and no sell positions
   if(!IsAnyOpenPosition() && OpenPositionType != 1)
   {
      MqlTradeRequest request;
      MqlTradeResult result;

      ZeroMemory(request);
      request.action = TRADE_ACTION_DEAL;
      request.symbol = symbol;
      request.volume = lotSize;
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      request.deviation = 3;
      request.magic = 12345;
      request.comment = "Odgwu_TargetX2_EA";

      if(!OrderSend(request, result))
      {
         Print("OrderSend failed with error #", GetLastError());
      }
      else
      {
         Print("OrderSend placed successfully");
         OpenPositionType = 0; // Update the type of open positions
      }
   }
}

// Function to execute a sell order
void Sell(string symbol, double lotSize)
{
   // Check if there are less than 5 open positions and no buy positions
   if(!IsAnyOpenPosition() && OpenPositionType != 0)
   {
      MqlTradeRequest request;
      MqlTradeResult result;

      ZeroMemory(request);
      request.action = TRADE_ACTION_DEAL;
      request.symbol = symbol;
      request.volume = lotSize;
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(symbol, SYMBOL_BID);
      request.deviation = 3;
      request.magic = 12345;
      request.comment = "Odgwu_TargetX2_EA";

      if(!OrderSend(request, result))
      {
         Print("OrderSend failed with error #", GetLastError());
      }
      else
      {
         Print("OrderSend placed successfully");
         OpenPositionType = 1; // Update the type of open positions
      }
   }
}

// Function to close all positions
void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      MqlTradeRequest request;
      MqlTradeResult result;

      ZeroMemory(request);
      request.action = TRADE_ACTION_REMOVE;
      request.position = ticket;

      if(!OrderSend(request, result))
      {
         Print("OrderSend failed with error #", GetLastError());
      }
      else
      {
         Print("OrderSend placed successfully");
      }
   }
}

// Function to check if the balance has doubled
bool HasBalanceDoubled()
{
   double CurrentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   return CurrentBalance >= 2 * InitialBalance;
}

//+------------------------------------------------------------------+
//| OnInit function                                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   // TODO: Add your initialization logic here
   // For example, you could initialize the Q-table and the initial balance
   InitializeQTable();
   InitialBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnTick function                                                  |
//+------------------------------------------------------------------+
void OnTick()
{
   // TODO: Add your trading logic here
   // For example, you could determine the state, choose an action, and then execute a buy or sell order based on the action
   string symbol = _Symbol; // Current symbol
   ENUM_TIMEFRAMES period = _Period; // Current period
   int shift = 0; // Current bar

   // Determine the state
   int state = DetermineState(symbol, period, shift);

   // Choose an action
   int action = ChooseAction();

   // Check if there are less than 5 open positions
   if(!IsAnyOpenPosition())
   {
      // Execute a buy or sell order based on the action
      if (action == 0)
      {
         Buy(symbol, 0.01/*lotSize*/); // Buy 0.1 lot
      }
      else if (action == 1)
      {
         Sell(symbol, 0.01/*lotSize*/); // Sell 0.1 lot
      }
   }

   // Determine the reward
   double reward = DetermineReward(action, symbol, period, shift);

   // Update the Q-table
   UpdateQTable(CurrentState, CurrentAction, reward, state);

   // Update the current state and action
   CurrentState = state;
   CurrentAction = action;

   // Check if the balance has doubled
   if (HasBalanceDoubled())
   {
      // If the balance has doubled, close all positions
      CloseAllPositions();
   }
}
