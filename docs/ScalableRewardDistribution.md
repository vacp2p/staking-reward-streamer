### Reward Distribution Formulas

<!-- prettier-ignore -->
> [!IMPORTANT] 
> All formulas in this section are integral to understanding the reward distribution mechanism within the staking protocol. They ensure accurate and fair allocation of rewards based on staked balances and Multiplier Points (MP).

---

#### Definitions

##### $R_i \rightarrow$ Cumulative Reward Index

The **reward index** represents the cumulative rewards distributed per unit of total weight (staked balance plus Multiplier Points) in the system. It is a crucial component for calculating individual rewards.

$$
R_i = R_i + \left( \frac{R_{new} \times \text{SCALE\_FACTOR}}{W_\mathbb{System}} \right)
$$

Where:

- **$R_{new}$**: The amount of new rewards added to the system.
- **$W_\mathbb{System}$**: The total weight in the system, calculated as the sum of all staked balances and total Multiplier Points.
- **$\text{SCALE\_FACTOR}$**: Scaling factor to maintain precision.

---

##### $W_\mathbb{System} \rightarrow$ Total Weight

The **total weight** of the system is the aggregate of all staked tokens and Multiplier Points (MP) across all accounts. It serves as the denominator in reward distribution calculations.

$$
W_\mathbb{System} = \mathbb{System}\cdot a_{\text{bal}} + \mathbb{System}\cdot mp_{\Sigma}
$$

Where:

- **$\mathbb{System}\cdot a_{\text{bal}}$**: Total tokens staked in the system.
- **$\mathbb{System}\cdot mp_{\Sigma}$**: Total Multiplier Points accumulated in the system.

---

##### $\mathbb{Account}\cdot W \rightarrow$ Account Weight

The **account weight** for an individual account $j$ combines its staked balance and accumulated Multiplier Points. This weight determines the proportion of rewards the account is entitled to.

$$
\mathbb{Account}\cdot W = \mathbb{Account}\cdot a_{bal} + \mathbb{Account}\cdot mp_{\Sigma}
$$

Where:

- **$\mathbb{Account}\cdot a_{bal}$**: Staked balance of account $j$.
- **$\mathbb{Account}\cdot mp_{\Sigma}$**: Total Multiplier Points of account $j$.

---

#### Reward Index Update

The **reward index** is updated whenever new rewards are added to the system. This update ensures that rewards are accurately tracked and distributed based on the current total weight.

1. **Calculate New Rewards:**

   $$
   R_{new} = R_{bal} - R_{accounted}
   $$

   Where:

   - **$R_{bal}$**: Current balance of reward tokens in the contract.
   - **$R_{accounted}$**: Total rewards that have already been accounted for.

2. **Update Reward Index:**

   $$
   R_i = R_i + \left( \frac{R_{new} \times \text{SCALE\_FACTOR}}{W_\mathbb{System}} \right)
   $$

3. **Account for Distributed Rewards:**

   $$
   R_{accounted} = R_{accounted} + R_{new}
   $$

---

#### Reward Calculation for Accounts

Each account's rewards are calculated based on the difference between the current reward index and the account's last recorded reward index. This ensures that rewards are distributed proportionally and accurately.

1. **Calculate Reward Index Difference:**

   $$
   \Delta \mathbb{Account}\cdot R_i = \mathbb{System}\cdot R_i - \mathbb{Account}\cdot R_i 
   $$

2. **Calculate Reward for Account $j$:**

   $$
   \text{reward}_j = \frac{\mathbb{Account}\cdot W \times \Delta \mathbb{Account}\cdot R_i}{\text{SCALE\_FACTOR}}
   $$

3. **Update Account Reward Index:**

   $$
   \mathbb{Account}\cdot R_i = R_i
   $$

---

#### Distribute Rewards

When distributing rewards to an account, ensure that the reward does not exceed the contract's available balance. Adjust the accounted rewards accordingly to maintain consistency.

1. **Determine Transfer Amount:**

   $$
   \text{amount} = \min(\text{reward}_j, R_{bal})
   $$

2. **Adjust Accounted Rewards:**

   $$
   R_{accounted} = R_{accounted} - \text{amount}
   $$

3. **Transfer Reward Tokens:**

   $$
   \text{REWARD\_TOKEN.transfer}(j, \text{amount})
   $$

---

#### Multiplier Points (MP) Accrual

Multiplier Points (MP) enhance the staking power of participants, allowing them to earn greater rewards based on their staked amounts and lockup durations.

##### Accrue Multiplier Points for an Account

Multiplier Points accrue over time based on the staked balance and the predefined annual MP rate.

$$
\Delta mp_j = \frac{\Delta t \times \mathbb{Account}\cdot a_{bal} \times \text{MP\_RATE\_PER\_YEAR}}{365 \times \text{T\_DAY} \times \text{SCALE\_FACTOR}}
$$

Where:

- **$\Delta t$**: Time elapsed since the last MP accrual.
- **$\mathbb{Account}\cdot a_{bal}$**: Staked balance of account $j$.
- **$\text{MP\_RATE\_PER\_YEAR}$**: Annual rate at which MP accrue.

Accrued MP is capped by the account's maximum MP:

$$
\Delta mp_j = \min\left( \Delta mp_j, mp_{\mathcal{M},j} - \mathbb{Account}\cdot mp_{\Sigma} \right)
$$

Update the account's MP:

$$
\mathbb{Account}\cdot mp_{\Sigma} = \mathbb{Account}\cdot mp_{\Sigma} + \Delta mp_j
$$

---

#### Summary of Reward Calculation

At any given point, the **total reward** accumulated by an account $j$ is calculated as follows:

$$
\text{reward}_j = \frac{(\mathbb{Account}\cdot a_{bal} + \mathbb{Account}\cdot mp_{\Sigma}) \times (R_i - \mathbb{Account}\cdot R_i)}{\text{SCALE\_FACTOR}}
$$

This formula ensures that rewards are distributed proportionally based on both the staked tokens and the accrued Multiplier Points, adjusted by the changes in the global reward index since the last reward calculation for the account.

---

#### $\mathcal{f}^{\text{updateRewardIndex}}(\mathbb{System}) \longrightarrow$ Update Reward Index

Calculates and updates the global reward index based on newly added rewards and the current total weight in the system.

$$
\boxed{
	\begin{equation}
		\mathcal{f}^{\text{updateRewardIndex}}(\mathbb{System}) = R_i + \left( \frac{R_{new} \times \text{SCALE\_FACTOR}}{W_\mathbb{System}} \right)
	\end{equation}
}
$$

Where:

- **$R_{new}$**: Calculated as $R_{bal} - R_{accounted}$.
- **$W_\mathbb{System}$**: Defined as $\mathbb{System}\cdot a_{\text{bal}} + \mathbb{System}\cdot mp_{\Sigma}$.

---

#### $\mathcal{f}^{\text{calculateReward}}(\mathbb{Account}\cdot a_{bal}, \mathbb{Account}\cdot mp_{\Sigma}, R_i, \mathbb{Account}\cdot R_i) \longrightarrow$ Calculate Account Reward

Calculates the reward for an account $j$ based on its staked balance, Multiplier Points, and the change in the global reward index.

$$
\boxed{
	\begin{equation}
		\mathcal{f}^{\text{calculateReward}}(\mathbb{Account}\cdot a_{bal}, \mathbb{Account}\cdot mp_{\Sigma}, R_i, \mathbb{Account}\cdot R_i) = \frac{(\mathbb{Account}\cdot a_{bal} + \mathbb{Account}\cdot mp_{\Sigma}) \times (R_i - \mathbb{Account}\cdot R_i)}{\text{SCALE\_FACTOR}}
	\end{equation}
}
$$

Where:

- **$\mathbb{Account}\cdot a_{bal}$**: Staked balance of account $j$.
- **$\mathbb{Account}\cdot mp_{\Sigma}$**: Total Multiplier Points of account $j$.
- **$R_i$**: Current cumulative reward index.
- **$\mathbb{Account}\cdot R_i$**: Reward index at the last update for account $j$.
- **$\text{SCALE\_FACTOR}$**: Scaling factor to maintain precision.

