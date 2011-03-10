function [] = spikeserver(port)
addpath('tcp_udp_ip');
port_pause=0.010;
splice_pause=0.010;
%totalSpikesSent=0; for debugging, compare with totalSpikesReceived in
%spikeclient.m

timeout = 2;

    pnet('closeall');

    plx = PlxConnection();
    packetnum=1;
    if plx == 0
        error('Could not connect to Plexon server');
    else
        %Listen for an incoming connection on port #
        sock=pnet('udpsocket',port);
        
        if sock == -1
            error('Port %d is blocked',port);
        end

        %Only wait for 100 ms before giving up
        pnet(sock,'setreadtimeout',.002);
        pnet(sock,'setwritetimeout',1);

        disp('Waiting for client requests');
        
        clientisconnected = 0;
        connecttime = clock + 1;
        
        while 1
            
            msglen = pnet(sock,'readpacket');
            %Received a message
            if msglen > 0
                %Read instruction
                instruction = pnet(sock,'readline');
                fprintf('Received message from client... %s\n',instruction);
                switch instruction
                    case 'MARCO'
                        if clientisconnected
                            disp('Client was already previously connected');
                        end
                        clear wrapper;
                        wrapper = PlxConnection();
                        plx = wrapper.name;

                        %Flush buffer
                        [ndatapoints, ts, junk2] = PL_GetAD(plx);
                        
                        %Handshake request
                        %Read IP
                        clientip = pnet(sock,'readline');
                        clientport = pnet(sock,'read',[1,1],'uint16');
                        
                        %Get the current time from the Plexon server
                        %Currently hacky: wait for a message, then set
                        %currenttime to the timestamp within this
                        %message plus the polling interval for the Plexon
                        %server
                        PL_WaitForServer(plx,100);
                        [ndatapoints, ts, junk2] = PL_GetAD(plx); %2009a compatibility issue
                        allpars = PL_GetPars(plx);
                        currenttime = ts + ndatapoints/allpars(14); 
                        
                        
                        %connect to client and send a payload containing 
                        %the current time on the server
                        pnet(sock,'printf',['POLO' char(10)]);
                        pnet(sock,'write',currenttime);
                        %pnet(sock,'printf','Random garbagey garbage');
                        pnet(sock,'writepacket',clientip,double(clientport));
                        
                        fprintf('Client %s:%d connected\n',clientip,clientport);
                        
                        clientisconnected = 1;
                        
                        connecttime = clock;
                        
                        %Clear the spike buffer
                        [nspks,ts] = PL_GetTS(plx);
                    case 'KEEPALIVE'
                        connecttime = clock;
                    case 'DISCONNECT'
                        clientisconnected = 0;
                        connecttime = clock + 1;

                        %close port and reopen
                        pnet(sock,'close');
                        sock=pnet('udpsocket',port);

                end
            end
            
            %Don't send spikes for no reason
            if etime(clock,connecttime) > timeout
                disp('client disconnected');
                clientisconnected = 0;
                connecttime = clock + 1;
                
                %close port and reopen
                pnet(sock,'close');
                sock=pnet('udpsocket',port);
            end

            maxpacketsize = 1e3;
            
            if clientisconnected                
                %Send spikes
                %Stream data
                %PL_WaitForServer(plx);
                pause(port_pause)%100 ms pause to give client a chance to read port
                [nspks,ts] = PL_GetTS(plx);

                if nspks > 0 %Received spikes
                    fprintf('Sending %d spikes\n', nspks);
                    
                    
                    %Only forward spikes, not events
                    %ts = ts(ts(:,1) == 1,2:4);
                    %totalSpikesSent=totalSpikesSent+nspks;
                    
                    
                    
                    %Send spikes in batches of 1000*96
                    for ii = 1:ceil(size(ts,1)/maxpacketsize)
                        if ii >1 %DEBUGGING
                            disp('packet splicing ... if message is constant decrease port_pause and/or splice_pause in spikeserver.m')
                            pause(splice_pause)
                        end
                        %Write the spikes to the port
                        rg = (ii-1)*maxpacketsize+1:min(size(ts,1),ii*maxpacketsize);
                        pnet(sock,'printf',['SPIKES' char(10)]);
                        pnet(sock,'write', packetnum);
                        packetnum=packetnum+1;
                        %fprintf('Packet num %d\n', packetnum);
                        pnet(sock,'write',ts(rg,:));
                        pnet(sock,'writepacket',clientip,clientport);
                    end
                end
            end
        end
    end
end
