% (c) Copyright. Vishnu Pradeesh Lekshmanan 2019.
%%
close all;
clear;clc;
%% Symbols
%{
-------> X axis
|\
|-\
|tz\
V
Y axis
%}

syms t g real;

n_links = 10;

m = sym('m',[n_links,1],{'real','positive'}); % vector of mass of each link
l = sym('l',[n_links,1],{'real','positive'}); % vector of length of each links

tz = sym([],'real'); % vector of angles of each link from y axis
for i=1:n_links
    tzi = sprintf('tz%i(t)',i);
    tz = [tz;str2sym(tzi)];
end
%% Formulation
ls = l.*sin(tz); % l*sin(theta) for calculating x
lc = -l.*cos(tz); % l*cos(theta) for calculating y

x = cumsum(ls);
y = cumsum(lc);

xd = diff(x,t);
yd = diff(y,t);

%% Lagrangean
KE = sum(0.5*m.*(xd.^2 + yd.^2));
PE = sum(g.*m.*y);
L = KE - PE;

tt = sym('tt',[n_links,1],'real');
dt = sym('dt',[n_links,1],'real');
ddt = sym('ddt',[n_links,1],'real');

from = [tz,diff(tz,t),diff(tz,t,t)];
to = [tt,dt,ddt];
substiL = subs(L,from,to);
dL_dtheta = subs(gradient(substiL,tt),to,from);
ddt_dL_dtheta_dot = diff(subs(gradient(substiL,dt),to,from),t);
%% Euelr-Lagrange equations
substLag = subs(dL_dtheta-ddt_dL_dtheta_dot==0,from,to);
%% Differential equation
fprintf('Solving...\n');
[As,fs] = equationsToMatrix(substLag,ddt);
fprintf('Solved\n');

%% Differential equation function handles
A = matlabFunction(As,'Vars',{tt,dt,m,l,g});
f = matlabFunction(fs,'Vars',{tt,dt,m,l,g});

%% Parameters
mass = 0.1*ones(n_links,1);
len = 0.1*ones(n_links,1);
acc_g = 9.81;

%% ODE and IC
ddtheta = @(tt,dt)double(A(tt,dt,mass,len,acc_g)\f(tt,dt,mass,len,acc_g));

ic = [2*pi*rand(n_links,1)-pi;zeros(n_links,1)];

% odefun(0,zeros(4,1),ddtheta,n_links,10)

%% ODE solution
tn = 1000;
tf = 8;
tspan = linspace(0,tf,tn);
fprintf('Starting ODE45 for solving\n');
[~,y_out] = ode45(@(t,y)odefun(t,y,ddtheta,n_links,tf),tspan,ic);

%% Post processing
Theta = y_out(:,1:n_links);
ThetaDot = y_out(:,n_links+1:end);
X = [zeros(tn,1),cumsum(len'.*sin(Theta),2)];
Y = -[zeros(tn,1),cumsum(len'.*cos(Theta),2)];

%%
Kinetic_Energy = matlabFunction(subs(KE,from,to),'Vars',{tt,dt,m,l,g});
Potential_Energy = matlabFunction(subs(PE,from,to),'Vars',{tt,dt,m,l,g});
ke = zeros(tn,1);
pe = zeros(tn,1);
for i=1:tn
    ti = Theta(i,:)';
    dti = ThetaDot(i,:)';
    ke(i) = Kinetic_Energy(ti,dti,mass,len,acc_g);
    pe(i) = Potential_Energy(ti,dti,mass,len,acc_g);
end
%% Figures
axx = sum(len);
filename = 'animation.gif';
video_name = 'myVideo.avi';

delete(filename);
delete(video_name);

writerObj = VideoWriter(video_name);
writerObj.FrameRate = 50;
open(writerObj);

h = figure;
for i=1:tn
    clf;
    lx = X(i,:);
    ly = Y(i,:);
    plot(lx,ly,'bo-','LineWidth',3); hold on;
    plot(X(1:i,end),Y(1:i,end),'r');
    hold off;
    axis([-axx,axx,-axx,axx]);
    xlabel('X (m)');
    ylabel('Y (m)');
    ttl = sprintf('%i Link Pendulum',n_links);
    title(ttl);
    drawnow;
    frame = getframe(h);
    video_frames(i) = frame;
    im = frame2im(frame);
    [imind,cm] = rgb2ind(im,256);
    % Write to the GIF File
    if i == 1
        imwrite(imind,cm,filename,'gif', 'Loopcount',inf,'DelayTime',0.0001);
    else
        imwrite(imind,cm,filename,'gif','WriteMode','append','DelayTime',0.0001);
    end
    % write to video
    writeVideo(writerObj, frame);
end
close(writerObj);
close;

figure;
plot(tspan,ke,'r','LineWidth',2);
xlabel('Time (s)');
ylabel('Kinetic Energy (Nm)');
title('Kinetic Energy');
saveas(gcf,'kinetic_energy','png');
close;

figure;
plot(tspan,pe,'r','LineWidth',2);
xlabel('Time (s)');
ylabel('Potential Energy (Nm)');
title('Potential Energy');
saveas(gcf,'potential_energy','png');
close;
%% ODE function
function ydot = odefun(t,y,dy,n,tf)
fprintf('Completed: %f %%\n',t/tf*100);
tt = y(1:n);
dt = y(n+1:2*n);
ydot = [dt;dy(tt,dt)];
end