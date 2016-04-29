function [glob] = setup_noagg(param,glob,options)
%SETUP Prepares model objects for collocation procedure, no agg uncertainty
%-------------------------------------------------
%   This file prepares the Markov process (continuous or discretized), the
%   state space (across exogenous and endogenous variables), the function
%   space for approximating with, elements for use in approximation of the
%   stationary distribution, and basis functions for use in the collocation
%   procedure computations
%
%   INPUTS
%   - param     = model parameters
%   - glob      = global variables, including those used in the approximating functions
%   - options   = options, including continuous vs. discrete Markov, Tauchen vs. Rouwenhurst, 
%-------------------------------------------------

fprintf('Setup\n');

%% State space for idiosyncratic productivity
% One persistent shock
Nv              = glob.n(2);
switch options.discmethod
    case 'R'
        [P,vgrid,Pssv]      = setup_MarkovZ(Nv,param.sigv,param.rhov,1);
    case 'T'
        % INCLUDE TAUCHEN PROCESS HERE
end

vgrid0          = vgrid;

%% State space for endogenous variable pP
NpP              = glob.n(1);
curv             = glob.curv;
spliorder        = glob.spliorder;
pPgrid           = nodeunif(NpP,glob.pPmin.^curv(1),glob.pPmax.^curv(1)).^(1/curv(1));  % Adds curvature
pPgrid0          = pPgrid;    % Save for computing basis matrices in valfunc.m:line9

%% Function space and nodes (fspace adds knot points for cubic splines)
fspace          = fundef({'spli',pPgrid,0,spliorder(1)},...
                         {'spli',vgrid,0,spliorder(2)});
sgrid           = funnode(fspace);
s               = gridmake(sgrid);
Ns              = size(s,1);

%% Reconstruct grids after fspace added points for the spline (adds two knot points for cubic spline)
pPgrid          = sgrid{1};  
vgrid           = sgrid{2};  
NpP             = size(pPgrid,1); 
Nv              = size(vgrid,1);

%% Compute expectations matrix
glob.Phi        = funbas(fspace,s);
glob.Emat       = kron(P,speye(NpP));

%% Construct fine grid for histogram
pPgridf         = nodeunif(glob.nf(1),glob.pPmin.^glob.curv(1),glob.pPmax.^glob.curv(1)).^(1/glob.curv(1));
NpPf            = size(pPgridf,1);
vgridf          = vgrid;
Naf             = size(vgridf,1);
sf              = gridmake(pPgridf,vgridf);
Nsf             = size(sf,1);

glob.pPgridf    = pPgridf;
glob.vgridf     = vgridf;
glob.sf         = sf;
glob.Nsf        = Nsf;
glob.Phif       = funbas(fspace,sf);


%% Compute QV matrix for approximation of stationary distribution
glob.QV         = kron(P,ones(NpPf,1)); 

%% Create basis matrices (need only compute once)
glob.Phi_V      = splibas(vgrid0,0,spliorder(2),s(:,2));        % Used in Bellman / Newton computing expected values
glob.Phi_Vf     = splibas(vgrid0,0,spliorder(2),sf(:,2));       % Used when solving on fine grid

%% Create the basis matrix adjusting for SS money growth/price inflation
s_prime              = [s(:,1)*(1/exp(param.mu)), s(:,2)];
s_primef             = [sf(:,1)*(1/exp(param.mu)), sf(:,2)];
glob.Phiprime        = funbas(fspace,s_prime);     
glob.Phiprimef       = funbas(fspace,s_primef);


%% Declare additional global variables
glob.pPgrid0    = pPgrid0;          % unique elements of pP grid
glob.pPgrid     = pPgrid;           % full state space for pP grid
glob.vgrid0     = vgrid0;           % unique elements of a grid
glob.vgrid      = vgrid;            % full state space for a grid
glob.P          = P;                % transition probability matrix
glob.Pssv       = Pssv;             % stationary distribution for a
glob.Nv         = Nv;               % length of state space grid for a 
glob.NpP        = NpP;              % length of state space grid for pP
glob.fspace     = fspace;           % function space object for the model
glob.s          = s;                % full state space 
glob.Ns         = Ns;               % size of full state space
glob.s_prime    = s_prime;          % Adjusted for SS inflation

%% 
fprintf('Setup complete\n');

end


        
   