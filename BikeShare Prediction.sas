ods graphics on;
ods rtf file="bikeshare_output.rtf";


proc import out=bikeshare
datafile="BikeShare.csv"
dbms=csv replace; getnames=yes; datarow=2;
run;

data bikeshare_dummy;
set bikeshare;
*Creating dummy variables for season;
if season=1 	then winter=1;		else winter=0;
if season=2 	then spring=1;		else spring=0;
if season=3 	then summer=1;		else summer=0;
*Creating dummy variables for weather;
if weather=1 	then clear=1;		else clear=0;
if weather=2 	then cloudy=1;		else cloudy=0;
if weather=3 	then lt_rain=1;		else lt_rain=0;
*Using sas functions to get hour and day from datetime; 
hour=hour(datetime);
sas_day=datepart(datetime);
week_day=weekday(sas_day);
*Creating dummy variables for day; 
if week_day=1 	then sun=1;		else sun=0;
if week_day=2 	then mon=1;		else mon=0;
if week_day=3 	then tue=1;		else tue=0;
if week_day=4 	then wed=1;		else wed=0;
if week_day=5 	then thu=1;		else thu=0;
if week_day=6 	then fri=1;		else fri=0;
*Creating dummy variables for hour; 
if hour=0 	then h0 = 1;	else h0=0;
if hour=1 	then h1 = 1;	else h1=0;
if hour=2 	then h2 = 1;	else h2=0;
if hour=3 	then h3 = 1;	else h3=0;
if hour=4 	then h4 = 1;	else h4=0;
if hour=5 	then h5 = 1;	else h5=0;
if hour=6 	then h6 = 1;	else h6=0;
if hour=7 	then h7 = 1;	else h7=0;
if hour=8 	then h8 = 1;	else h8=0;
if hour=9 	then h9 = 1;	else h9=0;
if hour=10 	then h10 = 1;	else h10=0;
if hour=11 	then h11 = 1;	else h11=0;
if hour=12 	then h12 = 1;	else h12=0;
if hour=13 	then h13 = 1;	else h13=0;
if hour=14 	then h14 = 1;	else h14=0;
if hour=15 	then h15 = 1;	else h15=0;
if hour=16 	then h16 = 1;	else h16=0;
if hour=17 	then h17 = 1;	else h17=0;
if hour=18 	then h18 = 1;	else h18=0;
if hour=19 	then h19 = 1;	else h19=0;
if hour=20 	then h20 = 1;	else h20=0;
if hour=21 	then h21 = 1;	else h21=0;
if hour=22 	then h22 = 1;	else h22=0;
run;

*Splitting dataset into train and test; 
data train;
set bikeshare_dummy;
if mod(sas_day,4) > 0;
run;
data test;
set bikeshare_dummy;
if mod(sas_day,4) = 0;
run;

*Removing outliers using rstudent method;
proc reg data=train;
model count=holiday workingday temp atemp humidity windspeed spring summer fall winter clear cloudy lt_rain hv_rain sat sun mon tue wed thu fri h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 h10 h11 h12 h13 h14 h15 h16 h17 h18 h19 h20 h21 h22 h23 / vif;
run;
output out=train_rstudent (keep=sas_day count holiday workingday temp atemp humidity windspeed spring summer fall winter clear cloudy lt_rain hv_rain sat sun mon tue wed thu fri h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 h10 h11 h12 h13 h14 h15 h16 h17 h18 h19 h20 h21 h22 h23 r) rstudent=r;
run;

*comparing data distribution with theoretical distribution before removing outliers;
proc univariate data=train_rstudent normal;
var count;
qqplot count/normal (mu=est sigma=est);
run;

*Actual removal of outliers;
data train_clean;
set train_rstudent;
if abs(r)>2 then delete;
run;

*comparing data distribution with theoretical distribution after removing outliers;
proc univariate data=train_clean normal;
var count;
qqplot count/normal (mu=est sigma=est);
run;


*Correlation between temp and atemp;
proc corr data=train_clean;
var temp atemp;
run;
*PCA for temp and atemp;
proc princomp data=train_clean out=train_final;
var temp atemp;
run;
proc sgplot data=train_final;
scatter x=temp y=atemp;
ellipse x=temp y=atemp;
run;
proc sgplot data=train_final;
scatter x=prin1 y=prin2;
ellipse x=prin1 y=prin2;
run;

*Regression with stepwise;
proc reg data=train_final;
model count=holiday workingday prin1 humidity windspeed spring summer fall winter clear cloudy lt_rain hv_rain sat sun mon tue wed thu fri h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 h10 h11 h12 h13 h14 h15 h16 h17 h18 h19 h20 h21 h22 h23 /selection=stepwise vif;
run;

*Regression with significant variables;
proc reg data=train_final outest=regression_model;
model count=workingday prin1 humidity windspeed winter spring fall clear lt_rain sun fri h0 h1 h2 h5 h6 h7 h8 h9 h10 h11 h12 h13 h14 h15 h16 h17 h18 h19 h20 h21 h22 h23  / vif;
run;


*Creating Principle components fortemp and atemp of test dataset;
proc princomp data=test out=test_final;
var temp atemp;
run;

*Predicting count for test dataset;
proc score data=test_final score=regression_model type=parms predict out=test_predicted;
var workingday prin1 humidity windspeed winter spring fall clear lt_rain sun fri h0 h1 h2 h5 h6 h7 h8 h9 h10 h11 h12 h13 h14 h15 h16 h17 h18 h19 h20 h21 h22 h23;
run;


*Finding actual count for day;
proc means data=test_predicted;
class sas_day;
var count;
output out=test_count_day sum=count_day;
run;

*Finding predicted count for day;
proc means data=test_predicted;
class sas_day;
var model1;
output out=test_predicted_day sum=predicted_day;
run;

*merging actual and predicted count in result dataset;
data result;
merge test_count_day test_predicted_day;
by sas_day;
run;

*Correlation between actual and predicted value;
proc corr data=result;
var count_day predicted_day;
run;

ods graphics off;
ods rtf close;
************************************************END*************************************************************;
