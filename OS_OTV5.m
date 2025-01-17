%% basic screen clearing commands
clc; close all; clear;
%% importing the dataset
filename='userxitem_YM.xlsx';
userxitem_db=xlsread(filename);     % 484*945 for Yahoo! Movies
filename='TOPSIS.csv';
aggre=xlsread(filename);
db_size = size(userxitem_db);
%% Mean of each user
User_mean =  sum(userxitem_db,2)./sum(userxitem_db ~=0,2);
train_size= zeros(1,db_size(1));

%% Calculating multi-criteria frequency count
mcfc = zeros(db_size(1),1); % Preallocating the memory for the similarity
for actuser=1 :db_size(1)
    for g = 1:db_size(1)
        if g ~= actuser
            sim1=0; flag=700;
            for p=1:db_size(2)
                %%%%%%%
                if (aggre(actuser,p)~=0 && aggre(g,p)~=0)
                sim1 =sim1+(aggre(actuser,p)-aggre(g,p))^2;
                flag=555;
                end
            end
            if flag==555
            mcfc(g,actuser)=1/(1+(sqrt(sim1)));
            else
                 mcfc(g,actuser)=1;
            end
        else
            mcfc(g,actuser)=1;
        end
        flag=700;
    end
end

%% Generation of training and test data
y=0;
all_tp = [];
all_fp = [];
all_fn = [];
all_tn = [];

for train_test=.60:.10:.90
    y=y+1; precision=zeros(db_size(1),1); accuracy=zeros(db_size(1),1);
    recall=zeros(db_size(1),1); fmeasure=zeros(db_size(1),1); actuser_pi=zeros(db_size(1),1); actuser_ni=zeros(db_size(1),1);
    actuser_mae=zeros(db_size(1),1); actuser_rmse=zeros(db_size(1),1); actuser_corpred=zeros(db_size(1),1); fpr=zeros(db_size(1),1);
    
    for actuser=1 :db_size(1) % number of users
        sim1 = zeros(1,db_size(1)); % Preallocating the memory
        sim = zeros(db_size(1),1); % Preallocating the memory for the similarity
        for g = 1:db_size(1)
            if g ~= actuser
                new_db = find(userxitem_db(actuser,:)); %for user one ## at a time one user's rating
                train_size(1,actuser) = round(length(new_db)*train_test);  % training set
                ni = length(new_db)- train_size(1,actuser);
                train_index = new_db(:,1:train_size(1,actuser));
                test_index  = new_db(:,train_size(1,actuser)+1 : end);
                train_rat =zeros(1,train_size(1,actuser));
                for a=1:train_size(1,actuser)
                    train_rat(1,a) = userxitem_db(actuser,train_index(a));
                end
                actuser_mean = User_mean(actuser); %mean(train); % udate the mean of active user
                %% Calculating the similarity among different users
                
                train_n= find(userxitem_db(g,:));
                comm_rat=length(intersect(train_index,train_n));
                %% OS method
                denoL=exp(-(train_size(1,actuser)-comm_rat)/train_size(1,actuser));
                
                for d = 1: train_size(1,actuser)
                    if  userxitem_db(g,train_index(d)) ~=0
                        sim1(g) = sim1(g) + exp(-((train_rat(d)- userxitem_db(g,train_index(d)))/ max(train_rat(d), userxitem_db(g,train_index(d)))));
                        
                    end
                end
                
                if sim1(g)> 0        %true if at least one common item found between U and V
                    sim2=sim1(g)/comm_rat;
                    sim(g,1) = denoL*sim2;
                else
                    sim(g,1) = -99;
                end
            else
                sim(g,1)= -99;        %lowest possible similarity for self similarity
            end
        end
        %% sort the sim array
        global_sim(:,1)=sim(:,1).*mcfc(:,actuser); % Global similarity computation
        global_sim(:,2)=1:db_size(1);
        sortsim=sortrows(global_sim,-1);
        
%         sim(:,2)=1:db_size(1);
%         sortsim=sortrows(sim,-1);
        x=0;
        for top_k=10:10:70
            x=x+1;
            neighbour = sortsim(1:top_k,2);    %topK neighbours
            
            %% Prediction
            prediction=zeros(1,ni);
            pi = 0;
            for pr=1:ni            % movies to predict by neighbourhood set
                right = 0; norm_k = 0; count=0; % count the number of neighbours are able to give prediction
                for n=1:size(neighbour,1)             % neighbours
                    if  userxitem_db(neighbour(n,1),test_index(1,pr))~=0 % && userxitem_db(actuser,test_index(1,pr)) ~=0  #### already non-zero coz it's in test_index
                        right = right + (sim(neighbour(n,1),1) * (userxitem_db(neighbour(n,1),test_index(1,pr)) - User_mean(neighbour(n,1))));
                        norm_k = norm_k + sim(neighbour(n,1),1);
                        count = count+1;
                    end
                end
                if count ~=0 || (right ~=0 && norm_k ~= 0)
                    prediction(pr) =actuser_mean+ (right/norm_k);
                    pi=pi+1;
                else
                    prediction(pr) = 0;
                end
            end
            actuser_pi(actuser,x)=pi;  % total number of predicted items for actuser
            actuser_ni(actuser,x)=ni;   % total number of items in test set
            %% Coverage, MAE and RMSE of actuser
            mae=0; correct =0; rmse=0;
            for  item=1:ni
                if prediction(item) ~= 0
                    if round(prediction(item)) == userxitem_db(actuser,test_index(1,item))
                        correct = correct+1;
                    end
                    mae= mae + abs( prediction(item) - userxitem_db(actuser,test_index(1,item)));
                    rmse= rmse + ( prediction(item) - userxitem_db(actuser,test_index(1,item)))^2;
                end
            end
            if pi ~=0
                actuser_mae(actuser,x)=mae/pi;
                actuser_rmse(actuser,x)=sqrt(rmse/pi);
                actuser_corpred(actuser,x)=correct/pi;
            else
                actuser_mae(actuser,x)=0;
                actuser_rmse(actuser,x)=0;
                actuser_corpred(actuser,x)=0;
            end
            
            %% Precision,Recall & F-measure Accuracy
            thres=3; pr_size = size(prediction);
            tp=0;fn=0;fp=0;tn=0;
            for l=1:pr_size(2)
                p= prediction(l);
                a=userxitem_db(actuser,test_index(1,l));
                if (p~=0) && (a~=0)
                    if (p >= thres) && (a >= thres)
                        tp=tp+1;
                    elseif (a>p && a>=thres)
                        fn=fn+1;
                    elseif (p>a && p>=thres)
                        fp=fp+1;
                    else
                        tn=tn+1;
                    end
                end
            end
            
            if (tp+tn+fp+fn)~=0
                accuracy(actuser,x) = (tp+tn)/ (tp+tn+fp+fn);
            end
            if (tp+fp) ~=0
                precision(actuser,x) = tp/(tp+fp);
            end
            if (tp+fn)~=0
                recall(actuser,x)=tp/(tp+fn);
            end
            if recall(actuser,x)~=0 || precision(actuser,x) ~=0
                fmeasure(actuser,x)=(2*precision(actuser,x)*recall(actuser,x))/(precision(actuser,x)+recall(actuser,x));
            end
            if (fp+tn)~=0
                fpr(actuser,x)=fp/(fp+tn);
            end
            
        end
    end
    total1_coverage(y,:)= (round((sum(actuser_pi)./sum(actuser_ni))*10000))/10000;
    total2_MAE(y,:)= (round((sum(actuser_mae)./sum(actuser_mae ~=0))*10000))/10000;
    total3_RMSE(y,:)=(round((sum(actuser_rmse)./sum(actuser_rmse ~=0))*10000))/10000;
    total4_precision(y,:) = (round((sum(precision)./sum(precision ~=0))*10000))/10000;
    total5_recall(y,:)= (round((sum(recall)./sum(recall ~=0))*10000))/10000;
    total6_fm(y,:)= (round((sum(fmeasure)./sum(fmeasure ~=0))*10000))/10000;
    total7_accuracy(y,:)=(round((sum(accuracy)./sum(accuracy ~=0))*10000))/10000;
    total8_correct(y,:)=(round((sum(actuser_corpred)./sum(actuser_corpred ~=0))*10000))/10000;
    total9x_auc(y,:)=(round((sum(fpr)./sum(fpr ~=0))*10000))/10000;
end
