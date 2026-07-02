function outputMatrix = assessCounterbalancing(conditionOrder)
%> @fn assessCounterbalancing
%> @brief Compatibility wrapper for taskSequence.assessCounterbalancing.
%>
%> @param conditionOrder ordered integer condition sequence.
%> @return square matrix where A(i,j) is count of i preceding j.

outputMatrix = taskSequence.assessCounterbalancing(conditionOrder);
