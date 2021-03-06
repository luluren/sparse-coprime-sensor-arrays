function [Pair] = CoarrayTest(Mmax,Nmax,U1,U2,Aperture_End)
    %This script is designed to test whether or not it matters if M and N
    %must be coprime or multiples of U2 and U1 respectively, or if they can
    %be arbitrarily chosen. The only parameter tested is the coarray and
    %availability of lags given a certain M and N. Preliminary results show that  there are
    %choices of M and N which can assure that every lag is available. This
    %will increase the length of our continuous coarray used in Direct
    %MUSIC.
    
    Mrng = U2:Mmax;%Continuous Range of M
    Nrng = U1:Nmax;%Continuous Range of N
    PairNdx = 1; %Gives an pairs an index for storage
    Ln = zeros(length(Mrng),length(Nrng)); %This will hold magnitude of unavailable lags
%     L = zeros(length(Mrng),length(Nrng));%This will hold which lag is unavailable
    Pair = zeros(4,1);%Will have columns representing each pair where all lags
                    %are available. Row 1 will be M's and Row two will be N's.

        for M = Mrng
            sensorindicator = []; %sensor indicator must be emptied after a full range
                                  %of N has been reached, or it will simply
                                  %overwrite old values and keep the same
                                  %size as the maximum.
            for N = Nrng
                    
                    indexa = (0:U1:(M-1)*U1).';    indexb = (0:U2:(N-1)*U2).';
                    indexunion = unique([indexa' indexb']);
                    numSens = length(indexunion); %holds the number of sensors
                                                  %used for the current
                                                  %configuration of M and N
                    sensorindicator(indexunion+1) = 1;
                    numPos = length(sensorindicator);%holds the number of required
                                                    %continuous positions
                                                    %available for proper
                                                    %spacing
                    coarray = conv(sensorindicator,fliplr(sensorindicator));
                    temp = (length(coarray)-1)/2;
                    coarray(1:temp) = [];
                    %The unavailable lags in coarray are found
                    zeroindex = find(coarray==0);
                    %Ln will hold the number of unavailable lags for a
                    %particular M and N pair.
                    Ln(M+1-U2,N+1-U1) = length(zeroindex);
                    if isempty(zeroindex)
%                         L(M+1-U2,N+1-U1) = 0; %currently cannot hold a
%                         vector
                        Pair(:,PairNdx)= [M N numSens numPos]';
                        PairNdx = PairNdx + 1;
                    else
%                         L(M+1-U2,N+1-U1) = zeroindex; %Currently cannot
%                         hold a vector
                    end
                    %I want to show that for M and N that are arbitrary,
                    %and not coprime or multiples of the initail coprime
                    %values given by U2 and U1 respectively, that the
                    %number of available lags is affected in a negative
                    %way.
                    if length(sensorindicator)>Aperture_End
                        break
                    end
            end
        end
end
%Test with U1 = 2 and U2 = 3 show that N, initially equal to U1 = 2 only
%displayed complete lag availability in multiples of its original value. In
%other words N must be a full extension of its original coprime array value
%to acheive total lag availability. Results also show that M, intially
%equal to U2 = 3 displays total lag availability in multiples of its
%original value. These results indicate that as long as the original
%coprime array, the original choice of M and N giving us U2 and U1
%respectively, is extended in full periods, the coarray will have no holes
%and will remain continuous across the entire array. This should improve
%direct MUSICs ability to estimate DOA.
%An interesting result is that while N has to be a multiple of it's
%undersampling factor, M has two sets of possibilities. If M is equal to the 
%number of sensor positions given by the
%inital M and N, then it will display full lag availability in multiples of
%it's undersampling factor after that. 
%For Example. With U1 = 2 and U2 = 3, the necesary values of M and N for
%total lag availability are N = {2 4 6 8 10 ...} and M1 = {3 6 9 12 15...}
%and M2 = {5 8 11 14 17...}. Where NM1 and NM2 will both give a continuous
%coarray every time.
%Tests with a 5, 4 base pair show no inherantly continuous ranges for
%coarray possible.
        