function snr_snapshots_analysis_par2(snr,snapshots,reps,filename)
% analysis for mse's of different algorithms across snr and snapshots
    time_tot = tic;
    mse = zeros(1,length(snr),length(snapshots),2); %need 2 for d,dnew mse's
%     params_mse = zeros(reps,4); 
    flags_k = zeros(reps,2);
    flags = mse; % needs same preallocation
    d =zeros(1,reps);
    dnew = d;
    
    for cnt = 1:1
    for i_snr = 1:length(snr)
        for j_snapshot = 1:length(snapshots)
            tic
            disp(['snr,snapshots: ', num2str([snr(i_snr),snapshots(j_snapshot)])]);
            parfor k = 1:reps
                [d(1,k),dnew(1,k),flags_temp] = ...
                    directionEstimatesVersion5MSE(snr(i_snr),snapshots(j_snapshot));
                flags_k(k,:) = flags_temp;
            end
            d = mean(d);
            dnew = mean(dnew);
            mse(cnt,i_snr,j_snapshot,:) = [d dnew];
            flags(cnt,i_snr,j_snapshot,:) = mean(flags_k);
            toc
        end
    end
    end
    mse = squeeze(mse);
    flags = squeeze(flags);
    time_tot = toc(time_tot) %#ok<NASGU>
%     save([pwd '\' filename]);
    save(filename);
%     title_name = {'Product', 'Minimum', 'Direct', 'Full'};
%     for i = 1:4
%     f = figure;
%     sz = size(mse);
%     X = snr'.*ones(sz(1),sz(2));
%     Y = snapshots.*(ones(sz(1),sz(2)));
%     Z = mse(:,:,i);
% 
%     mesh(X,Y,Z);
%     title(['MSE for ' title_name{i}]);
%     xlabel('SNR');
%     ylabel('Snapshots');
%     zlabel('MSE');
%     set(gca,'Xdir','reverse','Ydir','reverse')
%     end
end

function [dMSE,dpMSE,flags]= directionEstimatesVersion5MSE(SNRdB,SampleSize)
        
        plotfigure = 1;
        M = 4; N = 6;
        U1 = 3; U2 = 2;
        
       plot_fig = 1;
        flag = 1;
    counter = -1;
    flags = zeros(1,2);
    while flag && counter < 100%%%%%If the data set is not good, we need to discard the data set and come back here
        counter = counter + flag;
        flag = 0;
        us = cosd(randi(181,[1 2])-1);
        numSources = length(us);
        lambda = 50;    d = lambda/2;    kx = 2*pi/lambda * us;
        %%%calculate noise variance for signal power 1
        vars = ones(1,numSources);
        varn = vars(1)*10^(-SNRdB/10);
        s = zeros(numSources,SampleSize);
        %%input signals: proper GaussianK0478768904
        for idx = 1:numSources
            s(idx,:) = (sqrt(vars(idx)/2)*randn(1,SampleSize) + 1i*sqrt(vars(idx)/2)*randn(1,SampleSize));
        end
        ApertureEnd = max([(M-1)*U1 (N-1)*U2]);%%%%The array starts at 0 and ends at 63
        
        %%steering vector
        v = zeros(ApertureEnd+1,1);
        %%%%%The vector will have the data for all sensors
        x = zeros(ApertureEnd+1,SampleSize);
        for idx = 1:numSources
            v(:,idx) = exp(1i*kx(idx)*(0:ApertureEnd)*d).';
            x = x + v(:,idx)*s(idx,:);
        end
        %%%Add proper Gaussian noise samples
        x = x + sqrt(varn/2)*randn(ApertureEnd+1,SampleSize) + 1i*sqrt(varn/2)*randn(ApertureEnd+1,SampleSize);

        indexa = (0:U1:(M-1)*U1).';    indexb = (0:U2:(N-1)*U2).';
        indexunion = unique([indexa' indexb']);
        %%%xa will be subarray 1 data. It will have zero values where
        %%%sensors are not present.
        xa = zeros(max(indexa)+1,SampleSize);
        %%%xb will be subarray 2 data. It will have zero values where
        %%%sensors are not present
        xb = zeros(max(indexb)+1,SampleSize);%%%This will be subarray 2 data
        xa(indexa+1,:) = x(indexa+1,:);%%%xa takes the data from x, but only where Subarray 1 has sensors
        xb(indexb+1,:) = x(indexb+1,:);%%%xb takes the data from x, but only where Subarray 2 has sensors
        xtotal(indexunion+1,:) = x(indexunion+1,:);%%%%this is the union of Subarray 1 and Subarray 2. This data will be
                                                   %%%%used in direct MUSIC
                                                   

        sensorindicator(indexunion+1) = 1;%%%%This will make a vector called sensorindicator that will have
                                          %%%%ones where Subarray1 or Subarray 2 have sensors and
                                          %%%%zeros where both Subarray1 and Subarray 2 don't have sensors
        coarray = conv(sensorindicator,fliplr(sensorindicator));%%%%coarray tells you how many different 
                                                                %%%%sensor  pairs there are for each lag                                                         %%%%
        lags = -max(indexunion):max(indexunion);
        %%%%We can remove the negative half of the coarray and lags because
        %%%%the information they have is redundant
        temp = (length(coarray)-1)/2;%%%%This is the number of negative elements that can be removed
        coarray(1:temp) = [];%%%%Removes the negative half of coarray
        lags(1:temp) = [];%%%%Removes the negative half of lags
        %%%%The coarray could have holes. Keep the longest hole-free and
        %%%%the associated lags.
        firstzeroindex = find(coarray==0,1);%%%finds the index of the first zero elementconv(a,b)
        %%%%if the firstzeroindex is not empty, remove the elements from
        %%%%coarray and lag starting at the first zero element
        if ~isempty(firstzeroindex)
            coarray(firstzeroindex:end) = [];
            lags(firstzeroindex:end) = [];
        end
        r = zeros(length(coarray),SampleSize);%%%%covariance estimates

        for kdx = 1:SampleSize
            dataset = xtotal(:,kdx);
            %%%%The convolution operation can actually be used to find
            %%%%autocorrelation as shown below, for each set of samples
            tempR = conv(dataset.',fliplr(conj(dataset.')));
            tempR(1:temp) = [];
            if ~isempty(firstzeroindex)
                tempR(firstzeroindex:end) = [];
            end
            r(:,kdx) = (tempR.')./(coarray.');
        end
        rnew = zeros(11,SampleSize);% Eleven is the length of lags for the set configuration    
        for kdx = 1:SampleSize
            dataset = xtotal(:,kdx);
            rnew(1,kdx) = xtotal(1,kdx)*conj(xtotal(1,kdx));%a correlation is made for each sensor
            rnew(2,kdx) = xtotal(3,kdx)*conj(xtotal(4,kdx));%pair
            rnew(3,kdx) = xtotal(3,kdx)*conj(xtotal(5,kdx));
            rnew(4,kdx) = xtotal(1,kdx)*conj(xtotal(4,kdx));
            rnew(5,kdx) = xtotal(1,kdx)*conj(xtotal(5,kdx));
            rnew(6,kdx) = xtotal(5,kdx)*conj(xtotal(10,kdx));
            rnew(7,kdx) = xtotal(1,kdx)*conj(xtotal(7,kdx));
            rnew(8,kdx) = xtotal(3,kdx)*conj(xtotal(10,kdx));
            rnew(9,kdx) = xtotal(1,kdx)*conj(xtotal(9,kdx));
            rnew(10,kdx) = xtotal(1,kdx)*conj(xtotal(10,kdx));
            rnew(11,kdx) = xtotal(1,kdx)*conj(xtotal(11,kdx));
            tempR = conv(dataset.',fliplr(conj(dataset.')));
            tempR(1:temp) = [];
            if ~isempty(firstzeroindex)
                tempR(firstzeroindex:end) = [];
            end
            r(:,kdx) = (tempR.')./(coarray.');
        end
        
        Restimate = mean(r,2);
        Rmatrix = toeplitz(Restimate.');    
        [eVecd, eVald] = eig(Rmatrix);
        eVald = diag(eVald);
        [~,sortindexd] = sort(eVald,'descend');
        eVecsortedd = eVecd(:,sortindexd);
        noiseBasisd = eVecsortedd(:,length(us)+1:end);
        Rndirect = noiseBasisd*noiseBasisd';
%%%%%%%%%%%%%%%%%%%NEW ONE
        Restimate = mean(rnew,2);
        Rmatrix = toeplitz(Restimate.');    
        [eVecd, eVald] = eig(Rmatrix);
        eVald = diag(eVald);
        [~,sortindexd] = sort(eVald,'descend');
        eVecsortedd = eVecd(:,sortindexd);
        noiseBasisd = eVecsortedd(:,length(us)+1:end);
        Rndirectnew = noiseBasisd*noiseBasisd';

        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%Algorithm 2 and 3: PRODUCT/MIN MUSIC%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
        count = 1;
        u = -1:0.001:1;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        Pdirect = zeros(size(u));%%%%direct MUSIC
        Pdirectnew = zeros(size(u));%%%%direct MUSIC
        for idx = u  
            vdirect = exp(-1i*pi * idx*(0:max(lags)).');
            vdirectnew = exp(1i*pi * idx*(0:10).');
            %%%%The three steering vectors above are equal right now, we
            %%%%might change their lengths later
            Pdirect(count) = 1/(vdirect'*Rndirect*vdirect);  
            Pdirectnew(count) = 1/(vdirectnew'*Rndirectnew*vdirectnew);  
            count = count + 1;        
        end
        Pdirect = 10*log10(abs(Pdirect/max(abs(Pdirect))));
        Pdirectnew = 10*log10(abs(Pdirectnew/max(abs(Pdirectnew))));
        if plotfigure
            close all;
            f = figure;    
            ax = axes('Parent', f, 'FontWeight', 'Bold', 'FontSize', 16,... 
            'Position',[0.267203513909224 0.11 0.496339677891654 0.815]);
            hold all;
            plot(ax, u, Pdirect, 'LineWidth', 3, 'Color', [0.6 0 0.6],'LineStyle','-');
            hold on;
            plot(ax, u, Pdirectnew, 'LineWidth', 3, 'Color', [0 0 1],'LineStyle','-.');
            grid on;
            hold on;
            xlabel('u=cos(\theta)', 'FontSize', 16, 'FontWeight', 'Bold');
            ylabel('Output, dB', 'FontSize', 16, 'FontWeight', 'Bold');
            xlim([-1 1]);
            lowerlimit = -15;
            ylim([lowerlimit 0]);
            %%%%The following loop marks the actual source locations by creating a
            %%%%line corresponding to each source location
            for idx = 1:length(us)
                hold on;
                plot([us(idx) us(idx)],[lowerlimit 0],'r:','LineWidth',2);
            end   
            legend('Direct','Partial Direct','Actual u_1','Actual u_2');
            hold on;
            set(gcf,'WindowState','maximized');        
        end
         %%%%%The rest of the program finds the peaks in our estimates and
    %%%%%computes the Mean Squared Errors
        MinPeakHeight = -12;
       [~,direct_locs] = findpeaks(Pdirect,u,'NPeaks',2,'MinPeakHeight',MinPeakHeight);
       [~,directNew_locs] = findpeaks(Pdirectnew,u,'NPeaks',2,'MinPeakHeight',MinPeakHeight);
         %%%%Compute the MSE. We don't know which peak locations correspond
         %%%%with which directions. So, we will associate _locs(1) with us(1)
         %%%%and compute the total MSE and call it mse1. Then, we will
         %%%%associate _locs(1) with us(2) and compute the total MSE and call
         %%%%it mse2. Then, actual MSE = min(mse1,mse2). Also, the
         %%%%estimate might have only one peaks. To account for that, first
         %%%%check the length of _locs and _locs. If they are not length 2,
         %%%%make them length 2 by repeating the same peak.
         
         %why would we do this and check if length(*_locs == 2) if we
         %arbitrarily make it at least two?
         if length(direct_locs)==1
             direct_locs = [direct_locs direct_locs];
         end
         if length(directNew_locs)==1
             directNew_locs = [directNew_locs directNew_locs];
         end

         
         if length(direct_locs)==2
            dMSE1 = sum((us-direct_locs).^2)/2;
            dMSE2 = sum((fliplr(us)-direct_locs).^2)/2;
            dMSE = min(dMSE1,dMSE2);
         else
%              disp('MAJOR ERROR for direct at snr and samplesize');
%              disp([SNRdB, SampleSize]);
             flag = 1;
             flags(1,1) = flags(1,1)+1;
         end
         if length(directNew_locs)==2
            fMSE1 = sum((us-directNew_locs).^2)/2;
            fMSE2 = sum((fliplr(us)-directNew_locs).^2)/2;
            dpMSE = min(fMSE1,fMSE2);
         else
%              disp('MAJOR ERROR for full at snr and samplesize');
%              disp([SNRdB, SampleSize]);
             flag = 1;
             flags(1,2) = flags(1,2)+1;
         end
    end
end

function x = ifourierTrans(X,nlower,nhigher,varargin)
%%%%X is the spectrum. nlower is the smallest lag. nhigher is the largest
%%%%lag
    deltau = 0.001;
    if nargin > 3
        deltau = varargin{1};
    end
    u = -1:deltau:1;
    temp1 = length(nlower:nhigher);
    temp2 = size(X,2);
    x = zeros(temp1,temp2);
    count = 1;
    for n = nlower:nhigher
        basis = exp(1i*pi*u*n);
        x(count,:) = 0.5*deltau*basis*X;
        count = count + 1;
    end
end