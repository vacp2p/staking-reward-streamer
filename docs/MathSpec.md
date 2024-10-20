# Mathematical Specification of Staking Protocol
> [!attention] All values in this document are expressed as unsigned integers.
## Constants
### Helper Constants
- $T_{DAY} = \pu{86400 \mathrm{s}}$ 
	Seconds in one day.
- $T_{YEAR} =  \lfloor365.242190 \times T_{DAY}\rfloor = \pu{31556925 \mathrm{s}}$ 
	Seconds in one mean tropical year.
- $SCALE_{FACTOR} = \pu{1 \times 10^{18} \mathrm{(1)}}$
	Scaling factor to maintain precision in calculations (dimensionless).
### Multiplier Points
- $T_{RATE} = \pu{12 \mathrm{s}}$
	The accrue rate period of time over which multiplier points are calculated.
- $MP_{APY} = \pu{100\%}$
	Annual percentage yield for multiplier points.
- $M_{MAX} = \pu{4 \mathrm{(1)}}$
	Maximum multiplier allowed for $\hat{mp}_\mathcal{A}$ (dimensionless).
### Thresholds
- $A_{MIN} = \lceil\tfrac{T_{YEAR}}{(T_{RATE} \times \frac{MP_{APY}}{100})}\rceil = \pu{2629744 \mathrm{tokens}}$
	Minimal value to generate 1 multiplier point in the accrue rate period ($T_{RATE}$).
	($A_{MIN} \propto T_{RATE}$)
- $T_{MIN} = 90 \times T_{DAY} = \pu{7776000 \mathrm{s}}$
	Minimum lockup period, equivalent to 90 days.
 - $T_{MAX_{YEARS}} = \pu{4 \mathrm{years}}$
	Maximum years of lockup period.
- $T_{MAX} = T_{MAX_{YEARS}} \times T_{YEAR} = \pu{126230400 \mathrm{s}}$
	Maximum lockup period in seconds.
## Variables
### System and User Parameters
- $\Delta a\rightarrow$ = Amount Difference
	Difference in amount, can be either reduced or increased depending on context.
- $\Delta t\rightarrow$ Time Difference of last accrual.  
	The time difference defined as: 
	$$
	\Delta t = t_{now} - t_{last}, \quad \text{where} \; \Delta t > T_{RATE}
	$$
- $t_{lock}\rightarrow$ = Time Lock Duration 
	A user-defined duration for which $a_{bal}$ remains locked.
- $t_{now}\rightarrow$ = Time Now
	The current timestamp seconds since the Unix epoch (January 1, 1970).  
- $t_{lock, \Delta}\rightarrow$ = Time Lock Remaining Duration 
	Seconds $a_{bal}$ remains locked, expressed as:
	$$
	\begin{aligned}
	&t_{lock, \Delta} = max(t_{lock,end},t_{now}) - t_{now} \\ \small\text{ where: }\normalsize\quad & t_{lock, \Delta} = 0\;\text{ or }\;T_{MIN} \le t_{lock, \Delta} \le T_{MAX}\end{aligned}$$
### State Related
- $a_{bal}\rightarrow$ = Amount of Balance
	Amount of tokens in balance, where $a_{bal} \ge A_{MIN}$.
- $t_{lock,end}\rightarrow$ = Time Lock End
	Timestamp marking the end of the lock period, it state can be defined as: $$t_{lock,end} = \max(t_{now}, t_{lock,end}) + t_{lock}$$ The value of $t_{lock,end}$ can be updated only within the functions:
	- $\mathcal{f}^{stake}(\tiny\mathbb{Account}\normalsize, \Delta a, \Delta t_{lock})$;
	- $\mathcal{f}^{lock}(\tiny\mathbb{Account}\normalsize, \Delta t_{lock})$;
- $t_{last}\rightarrow$ Time of Accrual
	Timestamp of the last accrued time, it state can be defined as:$$t_{last} = t_{now}$$The value of $t_{last}$ can is updated by all functions that change state:
	- $f^{accrue}(\tiny\mathbb{Account}\normalsize, a_{bal},\Delta t)$,
	- $\mathcal{f}^{stake}(\tiny\mathbb{Account}\normalsize, \Delta a, \Delta t_{lock})$;
	- $\mathcal{f}^{lock}(\tiny\mathbb{Account}\normalsize, \Delta t_{lock})$;
	- $\mathcal{f}^{unstake}(\tiny\mathbb{Account}\normalsize, \Delta a)$; 
- $mp_\mathcal{M}\rightarrow$ Maximum Multiplier Points
	Maximum value that $mp_\Sigma$ can reach.
	Relates as $mp_\mathcal{M} \propto a_{bal} \cdot (t_{lock} + M_{MAX})$. 
	Altered by functions that change the account state: 
	- $\mathcal{f}^{stake}(\tiny\mathbb{Account}\normalsize, \Delta a, \Delta t_{lock})$;
	- $\mathcal{f}^{lock}(\tiny\mathbb{Account}\normalsize, \Delta t_{lock})$;
	- $\mathcal{f}^{unstake}(\tiny\mathbb{Account}\normalsize, \Delta a)$.
	
	It's state can be expressed as the following state changes:
	1. Increase in balance and lock: $$
		\begin{aligned} 
			mp_\mathcal{M} &= mp_\mathcal{M} + mp_\mathcal{A}(\Delta a, M_{MAX} \times T_{YEAR}) \\
			&\quad + mp_\mathcal{B}(\Delta a, t_{lock,\Delta} + t_{lock}) \\
			&\quad + mp_\mathcal{B}(a_{bal}, t_{lock}) \\
			&\quad + mp_\mathcal{I}(\Delta a) 
		\end{aligned}
		$$
	2. Increase in balance only: $$
		\begin{aligned} mp_\mathcal{M} &= mp_\mathcal{M} + mp_\mathcal{A}(\Delta a, M_{MAX} \times T_{YEAR}) \\ &\quad + mp_\mathcal{B}(\Delta a, t_{lock,\Delta}) \\ &\quad + mp_\mathcal{I}(\Delta a) \end{aligned}
		$$
	3. Increase in lock only: $$
		\begin{aligned} mp_\mathcal{M} &= mp_\mathcal{M} + mp_\mathcal{B}(a_{bal}, t_{lock}) \end{aligned}
		$$
	4. Decrease in balance: $$
	\begin{aligned} mp_\mathcal{M} &= mp_\mathcal{M} - mp_\mathcal{R}(mp_\mathcal{M}, a_{bal}, \Delta a) \end{aligned}
	$$
- $mp_{\Sigma}\rightarrow$ Total Multiplier Points 
	Altered by all functions that change state:  
	- $\mathcal{f}^{stake}(\tiny\mathbb{Account}\normalsize, \Delta a, \Delta t_{lock})$;
	- $\mathcal{f}^{lock}(\tiny\mathbb{Account}\normalsize, \Delta t_{lock})$;
	- $\mathcal{f}^{unstake}(\tiny\mathbb{Account}\normalsize, \Delta a)$;
	- $f^{accrue}(\tiny\mathbb{Account}\normalsize, a_{bal},\Delta t)$. 
	
	The state can be expressed as the following state changes: 	
	$$
	mp_{\Sigma} \longrightarrow mp_{\Sigma} \pm 
	\begin{cases}
		\begin{aligned} 
			& min(mp_\mathcal{M} - mp_\Sigma, \\
			  & \quad mp_\mathcal{A}(a_{bal},\, \Delta t))  
		\end{aligned} & \text{for every} \; T_{RATE}, \\ 
		\begin{aligned}
			& mp_\mathcal{B}(\Delta a,t_{lock, \Delta} + t_{lock}) \\ 
			& \quad + mp_\mathcal{B}(a_{bal}, t_{lock}) \\
			& \quad + mp_\mathcal{I}(\Delta a) 
		\end{aligned} & \Rightarrow a_{bal} \uparrow \land \; t_{lock,end} \uparrow, \\ 
		\begin{aligned}
			& mp_\mathcal{B}(\Delta a, t_{lock, \Delta}) \\
			& \quad + mp_\mathcal{I}(\Delta a) 
		\end{aligned} & \Rightarrow a_{bal} \uparrow, \\
		mp_\mathcal{B}(a_{bal}, t_{lock})  & \Rightarrow t_{lock,end} \uparrow, \\ 
	   -mp_\mathcal{R}(mp_{\Sigma}, a_{bal}, \Delta a) & \Rightarrow a_{bal} \downarrow \\
	\end{cases}
	$$
- $\small\mathbb{Account}\normalsize\rightarrow$ Account storage schema 
	Defined as following:
	$$
	\small \mathbb{Account} \normalsize \coloneqq \left\{ 
	\begin{aligned} 
		a_{bal} & : \small\text{balance}, \\ \normalsize
		t_{lock,end} & : \small\text{lock end}, \\ \normalsize
		t_{last} & : \small\text{last accrual}, \\ \normalsize
		mp_\Sigma & : \small\text{total MPs}, \\ \normalsize
		mp_\mathcal{M} & : \small\text{maximum MPs} 
	\end{aligned} \right\}
	$$
- $\small\mathbb{System}\normalsize\rightarrow$ System storage schema
	Defined as following:
	$$
	\small \mathbb{System} \normalsize \coloneqq \left\{ 
	\begin{aligned} 
	    \tiny\mathbb{Account}\mathrm{[\,]}\normalsize & : \small\text{accounts}, \\ \normalsize
		a_{bal} & : \small\text{total staked}, \\ \normalsize
		mp_\Sigma & : \small\text{MP supply}, \\ \normalsize
		mp_\mathcal{M} & : \small\text{MP supply max} 
		
	\end{aligned} \right\}
	$$
$\mathbb{Account} = \{ a_{bal}, t_{lock,end}, t_{last}, mp_\Sigma, mp_\mathcal{M} \}$$\Delta t_{lock} = \max(t_{lock,end}, t_{now}) - t_{now} \quad \text{where} \quad 0 \leq \Delta t_{lock} \leq T_{MAX} \quad \text{or} \quad \Delta t_{lock} = 0$
$
## Pure Mathematical Functions
>[!info] This function definitions represent direct mathematical input -> output methods, which don't change state.
### Definition: $\mathcal{f}{mp_\mathcal{I}}(\Delta a) \longrightarrow$ Initial Multiplier Points
Calculates the initial multiplier points (**MPs**) based on the balance change $\Delta a$. The result is equal to the amount of balance added.
$$
\boxed{\begin{equation}\mathcal{f}{mp_\mathcal{I}}(\Delta a) = \Delta a\end{equation}}
$$
Where 
- **$\Delta a$**: Represents the change in balance.
---
### Definition: $\mathcal{f}{mp_\mathcal{A}}(a_{bal}, \Delta t) \longrightarrow$ Accrue Multiplier Points
Calculates the accrued multiplier points (**MPs**) over a time period **$\Delta t$**, based on the account balance **$a_{bal}$** and the annual percentage yield $MP_{APY}$.
$$
\boxed{
\begin{equation}
\mathcal{f}mp_\mathcal{A}(a_{bal}, \Delta t) = \dfrac{a_{bal} \times \Delta t \times MP_{APY}}{100 \times T_{YEAR}}
\end{equation}
}
$$
Where
- **$a_{bal}$**: Represents the current account balance.
- **$\Delta t$**: The time difference or the duration over which the multiplier points are accrued, expressed in the same time units as the year (typically days or months).
- **$T_{YEAR}$**: A constant representing the duration of a full year, used to normalize the time difference **$\Delta t$**.
- **$MP_{APY}$**: The Annual Percentage Yield (APY) expressed as a percentage, which determines how much the balance grows over a year.
---
### Definition: $\mathcal{f}{mp_\mathcal{B}}(\Delta a, t_{lock}) \longrightarrow$ Bonus Multiplier Points
Calculates the bonus multiplier points (**MPs**) earned when a balance **$\Delta a$** is locked for a specified duration **$t_{lock}$**. It is equivalent to the accrued multiplier points function $\mathcal{f}mp_\mathcal{A}(\Delta a, t_{lock})$ but specifically applied in the context of a locked balance.
$$
\begin{aligned}
	&\;\mathcal{f}mp_\mathcal{B}(\Delta a, t_{lock})  = \mathcal{f}mp_\mathcal{A}(\Delta a, t_{lock}) \\
	&\boxed{\begin{equation}\mathcal{f}mp_\mathcal{B}(\Delta a, t_{lock})  = \dfrac{\Delta a \times t_{lock} \times MP_{APY}}{100 \times T_{YEAR}}\end{equation}}
\end{aligned}
$$
Where:
- **$\Delta a$**: Represents the amount of the balance that is locked.
- **$t_{lock}$**: The duration for which the balance **$\Delta a$** is locked, measured in units of seconds.
- **$T_{YEAR}$**: A constant representing the length of a year, used to normalize the lock period **$t_{lock}$** as a fraction of a full year.
- **$MP_{APY}$**: The Annual Percentage Yield (APY), expressed as a percentage, which indicates the yearly interest rate applied to the locked balance.
---
### Definition: $\mathcal{f}{mp_\mathcal{R}}(mp, a_{bal}, \Delta a) \longrightarrow$ Reduce Multiplier Points
Calculates the reduction in multiplier points (**MPs**) when a portion of the balance **$\Delta a$** is removed from the total balance **$a_{bal}$**. The reduction is proportional to the ratio of the removed balance to the total balance, applied to the current multiplier points **$mp$**.
$$
\boxed{\begin{equation}\mathcal{f}{mp_\mathcal{R}}(mp, a_{bal}, \Delta a) = \dfrac{mp \times \Delta a}{ a_{bal}}\end{equation}}
$$
 Where:
 - **$mp$**: Represents the current multiplier points.
 - **$a_{bal}$**: The total account balance before the removal of **$\Delta a$**.
 - **$\Delta a$**: The amount of balance being removed or deducted.
---
## State Functions
These function definitions represent methods that modify the state of both **$\mathbb{System}$** and **$\mathbb{Account}$**. They perform various pure mathematical operations to implement the specified state changes, affecting either the system as a whole and the individual account states.
### Definition: $\mathcal{f}_{stake}(\tiny\mathbb{Account}\normalsize,\Delta a, t_{lock}) \longrightarrow$ Stake Amount With Lock
_Purpose:_ Allows a user to stake an amount $\Delta a$ with an optional lock duration $t_{lock}$.
#### Steps
1. Calculate the New Remaining Lock Period ($\Delta t_{lock}$): $$\Delta t_{lock} = max(\tiny\mathbb{Account}\normalsize _\cdot t_{lock,end}, t_{now}) + t_{lock} - t_{now}$$
2. Verify Constraints:
	- Ensure new balance ($a_{bal}$ + $\Delta a$) meets the minimum amount ($A_{MIN}$): $$\tiny\mathbb{Account}\normalsize _\cdot a_{bal} + \Delta a > A_{MIN}$$
	- Ensure the New Remaining Lock Period ($\Delta t_{lock}$) is within allowed limits ($T_{MIN}$ and $T_{MAX}$):$$\Delta t_{lock} = 0\;\lor\;T_{MIN} \le \Delta t_{lock} \le T_{MAX}$$
3. Accrue Existing Multiplier Points (MPs):
	- Call the $\mathcal{f}_{accrue}(\tiny\mathbb{Account}\normalsize)$ function to update MPs and last accrual time.
4. Calculate Increased Bonus MPs ($\Delta \hat{mp}_\mathcal{B}$) for the Increased Balance ($\Delta a$) and Increased Lock Period ($t_{lock}$):
	- For the new amount ($\Delta a$) with the New Remaining Lock Period ($\Delta t_{lock}$): $$\Delta \hat{mp}_\mathcal{B} = \mathcal{f}mp_\mathcal{B}(\Delta a, \Delta t_{lock})$$
	- For extending the lock ($t_{lock}$) on the existing balance ($\tiny\mathbb{Account}\normalsize _\cdot a_{bal}$): $$\Delta \hat{mp}_\mathcal{B} = \Delta \hat{mp}_\mathcal{B} + \mathcal{f}mp_\mathcal{B}(\tiny\mathbb{Account}\normalsize _\cdot a_{bal}, t_{lock})$$
5. Calculate Increased Maximum MPs ($\Delta mp_\mathcal{M}$): $$\Delta mp_\mathcal{M} = \mathcal{f}mp_\mathcal{I}(\Delta a) + \Delta \hat{mp}_\mathcal{B} + \mathcal{f}mp_\mathcal{A}(\Delta a, M_{MAX} \times T_{YEAR})$$
6. Calculate Increased Total MPs ($\Delta mp_\Sigma$): $$\Delta mp_\Sigma = \mathcal{f}mp_\mathcal{I}(\Delta a) + \Delta \hat{mp}_\mathcal{B}$$
7. Update account state
	- Update account maximum MPs: $$\tiny\mathbb{Account}\normalsize _\cdot mp_\mathcal{M} = \tiny\mathbb{Account}\normalsize\cdot mp_\mathcal{M} + \Delta mp_\mathcal{M}$$
	- Update account total MPs: $$\tiny\mathbb{Account}\normalsize _\cdot mp_\Sigma = \tiny\mathbb{Account}\normalsize _\cdot mp_\Sigma + \Delta mp_\Sigma$$
	- Update account balance: $$\tiny\mathbb{Account}\normalsize _\cdot a_{bal} = \tiny\mathbb{Account}\normalsize _\cdot a_{bal} + \Delta a$$
	- Update account lock end time: $$\tiny\mathbb{Account}\normalsize _\cdot t_{lock,end} = max(\tiny\mathbb{Account}\normalsize _\cdot t_{lock,end}, t_{now}) + t_{lock}$$
8. Update system state
	- Update system maximum MPs: $$\tiny\mathbb{System}\normalsize _\cdot mp_\mathcal{M} = \tiny\mathbb{System}\normalsize _\cdot mp_\mathcal{M} + \Delta mp_\mathcal{M}$$
	- Update system total MPs: $$\tiny\mathbb{System}\normalsize _\cdot mp_\Sigma = \tiny\mathbb{System}\normalsize _\cdot mp_\Sigma + \Delta mp_\Sigma$$
	- Update system total staked amount: $$\tiny\mathbb{System}\normalsize _\cdot a_{bal} = \tiny\mathbb{System}\normalsize _\cdot a_{bal} + \Delta a$$
---
### Definition: $\mathcal{f}_{lock}(\tiny\mathbb{Account}\normalsize, t_{lock}) \longrightarrow$ Increase Lock
> [!info] Equivalent to $\mathcal{f}_{stake}(\tiny\mathbb{Account}\normalsize,0, t_{lock})$

_Purpose:_ Allows a user to lock the $\tiny\mathbb{Account}\normalsize _\cdot a_{bal}$ with a lock duration $t_{lock}$.
#### Steps
1. Calculate the New Remaining Lock Period ($\Delta t_{lock}$): $$\Delta t_{lock} = max(\tiny\mathbb{Account}\normalsize _\cdot t_{lock,end}, t_{now}) + t_{lock} - t_{now}$$
2. Verify Constraints:
	- Ensure the New Remaining Lock Period ($\Delta t_{lock}$) is within allowed limits:$$\Delta t_{lock} = 0\;\lor\;T_{MIN} \le \Delta t_{lock} \le T_{MAX}$$
3. Accrue Existing Multiplier Points (MPs):
	- Call the $\mathcal{f}_{accrue}(\tiny\mathbb{Account}\normalsize)$ function to update MPs and last accrual time.
4. Calculate Bonus MPs for the Increased Lock Period: $$\Delta \hat{mp}_\mathcal{B} = mp_\mathcal{B}(\tiny\mathbb{Account}\normalsize _\cdot a_{bal}, t_{lock})$$
5. Update account state:
	- Update maximum MPs: $$\tiny\mathbb{Account}\normalsize _\cdot mp_\mathcal{M} = \tiny\mathbb{Account}\normalsize _\cdot mp_\mathcal{M} + \Delta \hat{mp}_\mathcal{B}$$
	- Update total MPs: $$\tiny\mathbb{Account}\normalsize _\cdot mp_\Sigma = \tiny\mathbb{Account}\normalsize _\cdot mp_\Sigma + \Delta \hat{mp}_\mathcal{B}$$
	- Update lock end time: $$\tiny\mathbb{Account}\normalsize _\cdot t_{lock,end} = max(\tiny\mathbb{Account}\normalsize _\cdot t_{lock,end}, t_{now}) + t_{lock}$$
6. Update system state:
	- Update system maximum MPs: $$\tiny\mathbb{System}\normalsize _\cdot mp_\mathcal{M} = \tiny\mathbb{System}\normalsize _\cdot mp_\mathcal{M} + \Delta mp_\mathcal{B}$$
	- Update system total MPs: $$\tiny\mathbb{System}\normalsize _\cdot mp_\Sigma = \tiny\mathbb{System}\normalsize _\cdot mp_\Sigma + \Delta mp_\mathcal{B}$$

---
### Definition: $\mathcal{f}_{unstake}(\tiny\mathbb{Account}\normalsize, \Delta a) \longrightarrow$ Unstake Amount Unlocked
1. Verify constraints:
	- Ensure the account is not locked: $$\tiny\mathbb{Account}\normalsize _\cdot t_{lock,end} < t_{now}$$
	- Ensure that account have enough balance: $$\tiny\mathbb{Account}\normalsize _\cdot a_{bal} > \Delta a$$
	- Ensure that new balance ($\tiny\mathbb{Account}\normalsize _\cdot a_{bal} - \Delta a$) will be zero or more than minimum allowed: $$\tiny\mathbb{Account}\normalsize _\cdot a_{bal} - \Delta a = 0\;\lor\; \tiny\mathbb{Account}\normalsize _\cdot a_{bal} - \Delta a > A_{MIN}$$
2. Accrue Existing Multiplier Points (MPs):
	- Call the $\mathcal{f}_{accrue}(\tiny\mathbb{Account}\normalsize)$ function to update MPs and last accrual time.
3. Calculate reduced amounts:
	- For maximum MPs: $$\Delta mp_\mathcal{M} =\mathcal{f}mp_\mathcal{R}(\tiny\mathbb{Account}\normalsize _\cdot mp_\mathcal{M}, \tiny\mathbb{Account}\normalsize _\cdot a_{bal}, \Delta a)$$
	- For total MPs: $$\Delta  mp_\Sigma = \mathcal{f}mp_\mathcal{R}(\tiny\mathbb{Account}\normalsize _\cdot mp_\Sigma, \tiny\mathbb{Account}\normalsize _\cdot a_{bal}, \Delta a)$$
4. Update account state:
	- Update maximum MPs: $$\tiny\mathbb{Account}\normalsize _\cdot mp_\mathcal{M} = \tiny\mathbb{Account}\normalsize _\cdot mp_\mathcal{M} - \Delta mp_\mathcal{M}$$
	- Update total MPs:$$\tiny\mathbb{Account}\normalsize _\cdot mp_\Sigma = \tiny\mathbb{Account}\normalsize _\cdot mp_\Sigma - \Delta mp_\Sigma$$
	- Update balance: $$\tiny\mathbb{Account}\normalsize _\cdot a_{bal} = \tiny\mathbb{Account}\normalsize _\cdot a_{bal} - \Delta a$$
5. Update system state:
	- Update system maximum MPs: $$\tiny\mathbb{System}\normalsize _\cdot mp_\mathcal{M} = \tiny\mathbb{System}\normalsize _\cdot mp_\mathcal{M} - \Delta mp_\mathcal{M}$$
	- Update system total MPs:$$\tiny\mathbb{System}\normalsize _\cdot mp_\Sigma = \tiny\mathbb{System}\normalsize _\cdot mp_\Sigma - \Delta mp_\Sigma$$
	- Update system total staked amount:$$\tiny\mathbb{System}\normalsize _\cdot a_{bal} = \tiny\mathbb{System}\normalsize _\cdot a_{bal} - \Delta a$$
---
### Definition: $\mathcal{f}_{accrue}(\tiny\mathbb{Account}\normalsize) \longrightarrow$ Accrue Multiplier Points
1. Calculate the time period since last accrual:$$\Delta t = t_{now} - \tiny\mathbb{Account}\normalsize _\cdot t_{last}$$ 
2. Verify constraints:
	- Ensure the accrual period is greater than the minimum rate period:$$\Delta t > T_{RATE}$$
4. Calculate accrued MP for the accrual period:$$\Delta \hat{mp}_\mathcal{A} = min(\mathcal{f}mp_\mathcal{A}(\tiny\mathbb{Account}\normalsize _\cdot a_{bal},\Delta t) ,\tiny\mathbb{Account}\normalsize _\cdot mp_\mathcal{M} -  \tiny\mathbb{Account}\normalsize _\cdot mp_\Sigma)$$ 
5. Update account state:
	- Update total MPs: $$\tiny\mathbb{Account}\normalsize _\cdot mp_\Sigma = \tiny\mathbb{Account}\normalsize _\cdot mp_\Sigma + \Delta \hat{mp}_\mathcal{A}$$
	- Update last accrual time: $$\tiny\mathbb{Account}\normalsize _\cdot t_{last} = \tiny\mathbb{Account}\normalsize _\cdot t_{now}$$
6. Update system state:
	- Update system total MPs: $$\tiny\mathbb{System}\normalsize _\cdot mp_\Sigma = \tiny\mathbb{System}\normalsize _\cdot mp_\Sigma + \Delta \hat{mp}_\mathcal{A}$$
---
