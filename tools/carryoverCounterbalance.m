function condSequence = carryoverCounterbalance(numConds, cbOrder, reps, omitSelfAdjacencies)
%> @fn carryoverCounterbalance
%> @brief Compatibility wrapper for taskSequence.carryoverCounterbalance.
%>
%> Uses the Brooks/Kandel Euler-circuit method. For academic use cite:
%> Brooks, J.L. (2012). Counterbalancing for serial order carryover
%> effects in experimental condition orders. Psychological Methods.
%>
%> @param numConds number of unique conditions.
%> @param cbOrder order/depth of counterbalancing.
%> @param reps number of repetitions per carryover relationship.
%> @param omitSelfAdjacencies omit repeated adjacent conditions.
%> @return counterbalanced condition sequence.

condSequence = taskSequence.carryoverCounterbalance(numConds, cbOrder, reps, omitSelfAdjacencies);
