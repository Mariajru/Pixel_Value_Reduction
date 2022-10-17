%% Pixel value reduction using Barten's model and DWT.
% MariaJose Rueda (mariajoserdmnts@gmail.com) at InterDigital, France.

clear all; close all;

% Read the imagee
I = imread('cat3.jpeg');
figure('Name', 'Original Image'); imshow(I);
truesize
s = 0.102;	% Image size (m)
a = s/1024;	% Pixel size (used in the spatial fq calculation) (m)
d = 0.51;	% Distance from the screen (m)

%% DWT. Calculates the coefficiets of Vertical (V), Horizontal (H) 
%% and Diagonal (D) details.
% C: Wavelet decomposition vector. The vector C contains the 
    % approximation and detail coefficients organized by level.
        % Cr: wavelet decomposition vector of red channel
        % Cg: wavelet decomposition vector of green channel
        % Cb: wavelet decomposition vector of blue channel
% lvl_max: Maximum wavelet decomposition level.
% Coefficients (each column is one channel RGB).
        % V: vertical detail coefficients
        % H: horizontal detail coefficients
        % D: diagonal detail coefficients
% S: contains the dimensions of the wavelet coefficients by level.

% Maximum wavelet decomposition level
dim = size(I);
lvl_max = wmaxlev(dim, 'haar');

% DWT according lvl_max
[Cr,Sr] = wavedec2(I(:, :, 1), lvl_max, 'haar'); % Red channel
[Cg,Sg] = wavedec2(I(:, :, 2), lvl_max, 'haar'); % Green channel
[Cb,Sb] = wavedec2(I(:, :, 3), lvl_max, 'haar'); % Blue channel

% Coefficients * Barten's CSF matrix
z = zeros(dim(1), dim(1), 3);
% Max frequencies matrix
max_fq = zeros(dim(1),dim(1), 3);
% RGB to L*a*b
I_lab = rgb2lab(I);
for i = 1:lvl_max    % i: level
    % Extract the level Li detail coefficients
    [Hr,Vr,Dr] = detcoef2('all',Cr,Sr,i);
    [Hg,Vg,Dg] = detcoef2('all',Cg,Sg,i);
    [Hb,Vb,Db] = detcoef2('all',Cb,Sb,i);
    % RGB values 
    H(:,:,1) = Hr; H(:, :, 2) = Hg; H(:, :, 3) = Hb;
    V(:,:,1) = Vr; V(:, :, 2) = Vg; V(:, :, 3) = Vb;
    D(:,:,1) = Dr; D(:, :, 2) = Dg; D(:, :, 3) = Db;    
    % Asing the H, V, D values to each pixel in the real image
    H_pixel = zeros(dim(1),dim(1), 3);
    V_pixel = zeros(dim(1),dim(1), 3);
    D_pixel = zeros(dim(1),dim(1), 3);
    
    % Obtain spatial frequency with the level
    % a: pixel size (m)
    % d: distance from the screen (m)
    % fq_lvl: Hz
    % fq_spat: cycles/pixel
    % fq: cycles/degree
    scale = 2^i;
    fq_lvl = scal2frq(scale,'haar');
    fq_spat = fq_lvl/(2^i);    
    degree = 2*atan((a/(2))/d);
    fq = fq_spat/degree;
    
    % Set Barten's model values 
    % r_A: radius in m (pixel surface)
    % r_d: radius sphere in m (calculated with the distance d)
    % sr: solid angle in square steradians
    % X_0: angular object area in square degrees
    r_A = sqrt((a/2)^2+(a/2)^2);
    A = pi*(r_A^2);
    r_d = sqrt((a/2)^2+(d^2));
    sr = A/(r_d^2);
    X_0 = rad2deg(sr);
    for y = 1:dim(1)
        for x = 1:dim(1)
            % Luminance (imshow(I_lab(:,:,1),[0 100]))
            L = I_lab(y, x, 1);

            %% Barten Model (whithout surround factor)
            % fq: spatial frequency in cycles/degree
            % L: luminance in cd/m2
            % X_O: angular object area in square degrees
            arg1 = 5200*exp(-0.0016*fq^2*(1+100/L)^0.08);
            arg2 = 1+(144/(X_0^2))+0.64*fq^2;
            arg3 = 63/(L^0.83)+1/(1-exp(-0.02*fq^2));
            CSF_pixel = arg1/sqrt(arg2*arg3);  
            
            % Operation per each channel (RGB images)
            for channel = 1:3
                % Position of the pixel value (x, y) in the pixel of the  
                    % original image given the level i
                pos_y = ceil(y/(2^i));
                pos_x = ceil(x/(2^i));
                % Save the level pixel value in the dim(I) x dim(I) matrix,
                    % with same coordinates as the original pixels image
                H_pixel(y, x, channel) = H(pos_y, pos_x, channel);
                V_pixel(y, x, channel) = V(pos_y, pos_x, channel);
                D_pixel(y, x, channel) = D(pos_y, pos_x, channel);
                % The coefficients are multiplied by the Barten's model
                    % results
                value_h =  H_pixel(y, x, channel) * CSF_pixel;
                value_v =  V_pixel(y, x, channel) * CSF_pixel;
                value_d =  D_pixel(y, x, channel) * CSF_pixel;
                % We save the maximum value between the V, H, D 
                % coefficients 
                value = max([value_h, value_v, value_d]);
                % The frequency of the maximun multiplication value is
                    % saved in the matrix max_fq (u)
                if value > z(y, x, channel)
                    z(y, x, channel) = value;
                    max_fq(y, x, channel) = fq;
                end   
            end
        end
    end
    % We delete the variables H, V, D to avoid dimension error 
        % in the next level
    clear H;
    clear V;
    clear D;    
end

%% Human visual sensitivity at pixel location
S = zeros(dim(1), dim(1), 3);
% New pixel luminance
L_low = zeros(dim(1), dim(1));
for y = 1:dim(1)
	for x = 1:dim(1)
        for channel = 1:3
            fq = max_fq(y, x, channel);
            % Luminance
            L = I_lab(y, x, 1);
            
            %% Barten Model (whithout surround factor)
            % fq: spatial frequency in cycles/degree
            % L: luminance in cd/m2
            % X_O: angular object area in square degrees
            arg1 = 5200*exp(-0.0016*fq^2*(1+100/L)^0.08);
            arg2 = 1+(144/(X_0^2))+0.64*fq^2;
            arg3 = 63/(L^0.83)+1/(1-exp(-0.02*fq^2));
            CSF_pixel = arg1/sqrt(arg2*arg3); 
            % Save the result of the human visual sensitivity at pixel 
            % location
            S(y, x, channel) = CSF_pixel;
            
            %% New pixel luminance
            % Scale factor
            f = 0.9;
            % Minimum detectable modulation m(x) = 1/S(x)
            m = 1/S(y, x, channel);
            % New pixel luminance
            k = 0.96;   % Scale factor in the final result
            L_low(y, x) = (abs(L*((1-f*m)/(1+f*m))))*k;
        end 
	end
end

%% Display the image and results
% New image
I_lum = I_lab;
I_lum(:, :, 1) = L_low;
I_new = lab2rgb(I_lum);
figure('Name', 'New Image'); imshow(I_new);
truesize
% The subtraction between the two perceptual lightness values
L_old = I_lab(:, :,1);
L_new = I_lum(:, :,1);
L_reduction = L_old - L_new;
% Maximum reduction
max_r = max(L_reduction(:));
result1 = ['Maximum reduction: ', num2str(max_r)];
disp(result1);
% Minimum reduction
min_r = min(L_reduction(:));
result2 = ['Minumum reduction: ', num2str(min_r)];
disp(result2);
% Change percentage
L_sum = L_reduction;
L_sum(isnan(L_sum)) = 0;
S1 = sum(sum(L_sum));
S2 = sum(sum(L_old));
perc = (S1/S2)*100;
result3 = ['Percentage total image reduction: ', num2str(perc), ' %'];
disp(result3);
