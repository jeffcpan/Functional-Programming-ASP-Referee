%%%%%%%%%%%%%%%%%%%%%%%%%
%GENERATE a Search Space%
%%%%%%%%%%%%%%%%%%%%%%%%%

%For each case, max one assignment to a ref
{assign(CID,RID) : referee(RID,RTYPE,MAX_WORKLOAD,PREV_WORKLOAD,PREV_PAYMENT)} = 1 :- case(CID,CTYPE,EFFORT,DAMAGE,POSTC,PAYMENT).

%%%%%%%%%%%%%%%%%%
%Hard Constraints%
%%%%%%%%%%%%%%%%%%

%TotalWorkload of a referee (sum of effort of all cases assigned to that ref) but not exceed MAX_WORKLOAD
:- TotalWorkload = #sum{EFFORT,CID : case(CID,CTYPE,EFFORT,DAMAGE,POSTC,PAYMENT), assign(CID,RID)}, referee(RID,RTYPE,MAX_WORKLOAD,PREV_WORKLOAD,PREV_PAYMENT), TotalWorkload > MAX_WORKLOAD.

%Do not assign cases to referees that are not in charge of that region (aka pref = 0)
:- assign(CID,RID), case(CID,CTYPE,EFFORT,DAMAGE,POSTC,PAYMENT), referee(RID,RTYPE,MAX_WORKLOAD,PREV_WORKLOAD,PREV_PAYMENT), prefRegion(RID,POSTC,PREF), PREF==0.

%Do not assign cases to referees that are not in charge of that type of case (aka pref = 0)
:- assign(CID,RID), case(CID,CTYPE,EFFORT,DAMAGE,POSTC,PAYMENT), referee(RID,RTYPE,MAX_WORKLOAD,PREV_WORKLOAD,PREV_PAYMENT), prefType(RID,CTYPE,PREF), PREF==0.

%Cases with DAMAGE exceeding externalMaxDamage(d) must be given to internal referees (aka cannot be given to external referees)
:- assign(CID,RID), case(CID,CTYPE,EFFORT,DAMAGE,POSTC,PAYMENT), referee(RID,RTYPE,MAX_WORKLOAD,PREV_WORKLOAD,PREV_PAYMENT), externalMaxDamage(MAXDAMAGE), DAMAGE > MAXDAMAGE, RTYPE==e.

%%%%%%%%%%%%%%%%%%%%%%%
%Optimization Criteria%
%%%%%%%%%%%%%%%%%%%%%%%
%Optimize based on:
%req1. Minimize total payment to external referees
%req2. Balance overall payments to external referees. Minimize divergence from the average
%req3. Balance overall workload to all referees. Minimize divergence from the average
%req4. Prioritize cases with higher postal preferences. Minimize "cost", calculated by (3 - pref)
%req5. Prioritize cases with higher region preferences. Minimize "cost", calculated by (3 - pref)
%Minimize overall optimization formula: 16*req1 + 7*req2 + 9*req3 + 34*req4 + 34*req5

%req1. Calculate total payment to external referees
totalExternalPaymentNoPrev(TEPNP) :- TEPNP = #sum{PAYMENT : assign(CID,RID), case(CID,CTYPE,EFFORT,DAMAGE,POSTC,PAYMENT), referee(RID,RTYPE,MAX_WORKLOAD,PREV_WORKLOAD,PREV_PAYMENT), RTYPE==e}.

%req2. Balance overall payments to external referees. Minimize divergence from the average
externalPaymentNoPrev(RID, EPNP) :- EPNP = #sum{PAYMENT, CID : assign(CID,RID), case(CID,CTYPE,EFFORT,DAMAGE,POSTC,PAYMENT)}, referee(RID,RTYPE,MAX_WORKLOAD,PREV_WORKLOAD,PREV_PAYMENT), RTYPE==e.
externalPayment(RID, EP) :- EP = EPNP + PREV_PAYMENT, externalPaymentNoPrev(RID, EPNP), referee(RID,RTYPE,MAX_WORKLOAD,PREV_WORKLOAD,PREV_PAYMENT), RTYPE==e.
totalExternalPayment(TEP) :- TEP = #sum{EP, RID : externalPayment(RID, EP)}.
numOfExternalRefs(NOER) :- NOER = #count{RID : referee(RID,RTYPE,MAX_WORKLOAD,PREV_WORKLOAD,PREV_PAYMENT), RTYPE==e}.
avgExternalPayment(AEP) :- AEP = TEP / NOER, totalExternalPayment(TEP), numOfExternalRefs(NOER).
paymentDivergence(PD) :- PD = #sum{|EP - AEP|, RID : avgExternalPayment(AEP), externalPayment(RID, EP)}.

%req3. Balance overall workload to any referee. Minimize divergence from the average
workloadNoPrev(RID, WNP) :- WNP = #sum{PAYMENT, CID : assign(CID,RID), case(CID,CTYPE,EFFORT,DAMAGE,POSTC,PAYMENT)}, referee(RID,RTYPE,MAX_WORKLOAD,PREV_WORKLOAD,PREV_PAYMENT).
workload(RID, W) :- W = WNP + PREV_PAYMENT, workloadNoPrev(RID, WNP), referee(RID,RTYPE,MAX_WORKLOAD,PREV_WORKLOAD,PREV_PAYMENT).
totalWorkload(TW) :- TW = #sum{W, RID : workload(RID, W)}.
numOfRefs(NOR) :- NOR = #count{RID : referee(RID,RTYPE,MAX_WORKLOAD,PREV_WORKLOAD,PREV_PAYMENT)}.
avgWorkload(AW) :- AW = TW / NOR, totalWorkload(TW), numOfRefs(NOR).
workloadDivergence(WD) :- WD = #sum{|W - AW|, RID : avgWorkload(AW), workload(RID, W)}.

%req4. Calculate case type preference cost
casePrefCost(CPC) :- CPC = #sum{3 - PREF, CID : assign(CID,RID), case(CID,CTYPE,EFFORT,DAMAGE,POSTC,PAYMENT), referee(RID,RTYPE,MAX_WORKLOAD,PREV_WORKLOAD,PREV_PAYMENT), prefType(RID,CTYPE,PREF)}.

%req5. Calculate postal code type preference cost
postPrefCost(PPC) :- PPC = #sum{3 - PREF, CID : assign(CID,RID), case(CID,CTYPE,EFFORT,DAMAGE,POSTC,PAYMENT), referee(RID,RTYPE,MAX_WORKLOAD,PREV_WORKLOAD,PREV_PAYMENT), prefRegion(RID,POSTC,PREF)}.

#minimize{16*TEPNP + 7*PD + 9*WD + 34*CPC + 34*PPC, CID, RID : assign(CID,RID), totalExternalPaymentNoPrev(TEPNP), paymentDivergence(PD), workloadDivergence(WD), casePrefCost(CPC), postPrefCost(PPC)}.

#show assign/2.