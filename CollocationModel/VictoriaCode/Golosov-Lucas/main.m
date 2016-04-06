%{
This program sets up and calls the functions that
solve the Golosov-Lucas model.

Written by:     Victoria Gregory
Date:           3/28/2016
%}

clear all;
clc;
dbstop if error;
cd '/Users/victoriagregory/Dropbox/MenuCostsModel/CollocationModel/VictoriaCode/Golosov-Lucas'

%% Settings

% What to solve for
options.solvexL     = 'Y';      % Solve for p and L given a Y 
options.solveeq     = 'Y';      % Solve equilibrium
options.solveKS     = 'Y';      % Solve Krussel-Smith

% Tolerances, iterations
options.Nbell       = 2;        % Number of Bellman (Contraction) iterations
options.Nnewt       = 15;       % Maximum number of Newton steps
options.tolc        = 1e-8;     % Tolerance on value functions
options.tolgolden   = 1e-6;     % Tolerance for golden search
options.itermaxL    = 5000;     % Maximum iterations to find stationary dist L
options.tolL        = 1e-11;    % Tolerance on L

% Set-up for state space
glob.n          = [10,5];       % Number of nodes in each dimension
glob.nf         = [300,5];      % Number of points for x and nu in histogram L
glob.curv       = 1;            % Grid curvature for x on (0,1] (1 is no curvature)
glob.spliorder  = [3,1];        % Order of splines (always use linear if shocks are discrete (not AR1))
glob.xmin       = exp(-0.4);    % Lower bound on x
glob.xmax       = exp(0.5);     % Upper bound on x

% NOTE (VG): resulting k grid will be n(1)+spliorder(1)-1
% Creating the cubic spline space adds 3-1=2 points.

% Model parameters
param.rho       = 0.04;
param.gamma     = 2;
param.epsilon   = 7;
param.alpha     = 6;
param.eta       = 0.55;
param.sigmanu   = sqrt(0.011);
param.k         = 0.0025;
param.mu        = 0.0064;
param.sigmam    = sqrt(0);
param.R         = param.rho + param.mu;
param.beta      = exp(-param.R);

% Print / plot 
options.print       = 'Y';      % Print out c-solution convergence

%% Setup problem
fprintf('Setup\n');
[param,glob]    = setup_ss(param,glob,options);      
fprintf('Setup complete\n');

%% Solve only x and L for a given cbar
switch options.solvexL
    case 'Y'
        cbar                = 0.35;      % Conjectured value of cbar    
        options.cresult     = [];     % Holds previous solution for c. Empty in this case.
        eq                  = solve_xL(cbar,param,glob,options);  
        fprintf('cbarin = %1.2f,\tcbarout = %1.2f\n',cbar,eq.cbar);
end

%% Solve equilibrium
switch options.solveeq
    case 'Y'
        options.tolcbar     = 0.0001;           % Tolerance on cbar
        options.cbarlb      = 0.1;              % cbar lower bound
        options.cbarub      = 0.6;                % cbar upper boud
        options.itermaxcbar = 30;               % Max iterations of bisection
        options.eqplot      = 'Y'; 
        options.eqprint     = 'Y'; 
        options.print       = 'N';
        options.Loadc       = 'Y';              % For new guess of cbar use old c as starting guess
        options.plotSD      = 'N';              % If Y plot steady state distribution
        eq                  = solve_eq(param,glob,options); 
end


%% Plot stationary distribution and value functions

figure;
subplot(1,2,1)
L_reshape = reshape(eq.L,glob.nf(1),glob.nf(2));
density = sum(L_reshape,2);
plot(glob.xgridf,density)

subplot(1,2,2)
valfun = max(eq.v.vk,eq.v.vk);
valfun_reshape = reshape(valfun,glob.nf(1),glob.nf(2));
plot(glob.xgridf,valfun_reshape);

%% Replicate Figure 1

nu_plot = nodeunif(100,exp(-0.5),exp(0.5));
s_plot = gridmake(1,nu_plot);

% set up state space
glob.Phi_nu  = splibas(glob.nugrid0,0,glob.spliorder(2),s_plot(:,2));

% begin by plotting the middle line:
% price firm would pick if it can
% costlessly adjust: v.Pc
param.k         = 0;
v_mid           = solve_valfunc_GL(eq.c,s_plot,eq.cbar,param,glob,options,1);

% for each point in a, find price (lower and upper bound)
% at which firm is indifferent between changing and keeping
param.k       = 0.0025;     % turn the menu cost back on
x_low = zeros(1,length(nu_plot));
x_upp = zeros(1,length(nu_plot));

for n=1:length(nu_plot)
    
    % for the given level of a, set up the state space: lower bound
    xl               = 1000;
    x_plot_low       = nodeunif(xl,min(glob.xgrid),v_mid.Xc(n));
    x_plot_upp       = nodeunif(xl,v_mid.Xc(n),max(glob.xgrid));
    x_plot           = [x_plot_low; x_plot_upp(2:end)];
    x_plot_upp       = x_plot_upp(2:end);
    s_plot          = gridmake(x_plot,nu_plot(n));
    glob.Phi_nu     = splibas(glob.nugrid0,0,glob.spliorder(2),s_plot(:,2));
    
    % compute lower/upper bounds on price
    v           = solve_valfunc_GL(eq.c,s_plot,eq.cbar,param,glob,options,1);
    dist        = abs(v.vc - v.vk);
    [~,I_low]   = min(dist(1:xl));
    x_low(n)    = x_plot_low(I_low);
    [~,I_upp]   = min(dist(xl+1:end));
    x_upp(n)    = x_plot_upp(I_upp);
    
end

% make figure
figure;
plot(log(nu_plot),log(v_mid.Xc),'--','Color','k')
hold on;
plot(log(nu_plot),log(x_low),'LineWidth',2,'Color','b')
hold on;
plot(log(nu_plot),log(x_upp),'LineWidth',2,'Color','b')
%set(gca,'Xlim',[-0.5 0.5])
%set(gca,'Ylim',[-0.3 0.4])
grid on;
xlabel('Log Productivity')
ylabel('Log Real Price')
