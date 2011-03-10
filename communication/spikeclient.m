function [spikes] = spikeclient(selfip,selfport,remoteip,remoteport)
    spikes = [];
    
    pnet('closeall');
    initt0 = tic;
    
    while 1 %Auto reconnect on failure
        sock=pnet('udpsocket',selfport);
        if sock == -1
            error('Could not open port %d',selfport);
        end
        pnet(sock,'setwritetimeout',1);
        pnet(sock,'setreadtimeout',1);

        %Send request
        disp('Connecting to server');

        pnet(sock,'printf',['MARCO' char(10) selfip char(10)]);
        pnet(sock,'write',uint16(selfport));
        pnet(sock,'writepacket',remoteip,remoteport);

        %Receive a polo message from the server
        dbefore = 0;
        
        while 1
            size = pnet(sock,'readpacket');
            if size > 0
                %Awesome
                msg = pnet(sock,'readline');
                if strcmp(msg,'POLO')
                    %Received acknowledgement, sync times
                    disp('Connected to server');
                    remotet0 = pnet(sock,'read',[1,1],'double');
                    localt0 = toc(initt0);

                    while 1
                        %Receive messages
                        sze = pnet(sock,'readpacket');
                        if sze > 0
                            msg = pnet(sock,'readline');
                            if strcmp(msg,'SPIKES')
                                %Read spikes
                                pnet(sock,'read',[1,1],'double');
                                sze = sze - 7 - 8;
                                nspks = sze/(8*4);
                                if nspks ~= 0 %No spikes in this one
                                    data = pnet(sock,'read',[nspks,4],'double');
                                    if isempty(data)
                                        disp('Corrupt message received');
                                        break;
                                    end
                                    data(:,4) = data(:,4) - remotet0 + localt0;
                                    spikes = [spikes;data];
                                end
                            else
                                fprintf('Invalid message type received: %s\n',msg);
                                break;
                            end

                            dnow = toc(initt0);
                            if mod(dbefore,2) > mod(dnow,2)
                                %Send keep alive signal every 10 seconds
                                pnet(sock,'printf',['KEEPALIVE' char(10) selfip char(10)]);
                                pnet(sock,'write',int16(selfport));
                                pnet(sock,'writepacket',remoteip,remoteport);
                            end

                            if mod(dbefore,3) > mod(dnow,3)
                                %Plot the spikes in the last 5 seconds
                                tgt = spikes(spikes(:,3) - dnow + 1 > 0,:);
                                plot(tgt(:,3) - dnow + 1,tgt(:,1) + (tgt(:,2)-1)*128,'.');
                                drawnow;
                                spikes = [];
                            end

                            dbefore = dnow;
                        else
                            %timed out... either no spikes for a second or some network issue
                            %Try reconnecting
                            disp('Timeout receiving spikes');
                            break;
                        end
                    end
                else
                    fprintf('Received unknown message %s, waiting for POLO\n',msg);
                end
            else
                fprintf('Timed out waiting for server\n');
            end
        end
        pnet(sock,'close')
    end
end