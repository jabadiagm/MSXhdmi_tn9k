--Javier Abadía / jabadiagm@gmail.com
--Structure based on Multicomputer by Grant Searle:
--           http://searle.x10host.com/Multicomp/index.html

library ieee;
use ieee.std_logic_1164.all;
use  IEEE.STD_LOGIC_ARITH.all;
use  IEEE.STD_LOGIC_UNSIGNED.all;

entity MSX_Interceptor is
	port(

	   --74lvc245 buffer signals
	    --address bus
		ex_busAddress    : in std_logic_vector(7 downto 0);

		--data bus
		ex_busDataOut     : in std_logic_vector(7 downto 0);
		
		--control bus
		ex_busMreq_n     : in std_logic;
		ex_busIorq_n     : in std_logic;
		ex_busRd_n       : in std_logic;
		ex_busWr_n       : in std_logic;
		ex_busReset_n    : in std_logic;
		ex_clk_3m6         : in std_logic;
		
		--interrupt
		--ex_int_n         : out std_logic;

		--fpga signals
		ex_reset_n    : in  std_logic:='1';
        ex_clk_27m	  : in std_logic:='0';
        ex_btn0	      : in std_logic:='0';
		
        --hdmi out
        data_p    : out  STD_LOGIC_VECTOR(2 downto 0);
        data_n    : out  STD_LOGIC_VECTOR(2 downto 0);
        clk_p          : out    std_logic;
        clk_n          : out    std_logic;  	

        ex_led          : out  STD_LOGIC_VECTOR (5 downto 0)

	);
end MSX_Interceptor;

architecture struct of MSX_Interceptor is

	signal busAddress	            : std_logic_vector(7 downto 0);
	signal busDataOut               : std_logic_vector(7 downto 0);
		
	signal busMreq_n                : std_logic;
	signal busIorq_n                : std_logic;
	signal busRd_n                  : std_logic;
	signal busWr_n                  : std_logic;
	signal busReset_n               : std_logic;
	signal clk_3m6                  : std_logic;

	signal memWr_n					: std_logic :='1';
	signal memRd_n 					: std_logic :='1';

	signal ioWr_n					: std_logic :='1';
	signal ioRd_n 					: std_logic :='1';
	
    signal clk_100m                 : std_logic;
    signal clk_50m                  : std_logic;
    signal clk_25m                  : std_logic;
    signal clk_25mn                 : std_logic;
    signal clk_126m                 : std_logic;
    signal clk_126mn                : std_logic;
	signal clk_48k                  : std_logic:='0'; --pwm clock = 48KHz
	signal clk_48k_counter          : std_logic_vector (10 downto 0):=(others=>'0'); 
	signal clk10m                   : std_logic:='0'; --7 segments 10 MHz
	signal clk10mCounter            : std_logic_vector (3 downto 0):=(others=>'0');
    signal clk_1m8                  : std_logic:='0'; --psg clock 3.57/2 = 1.8 MHz   

    signal reset : std_logic:='0';
    signal reset_n : std_logic;

    --f18a signals
	signal f18a_csw_n : std_logic:='1'; --VDP write request
	signal f18a_csr_n : std_logic:='1'; --VDP read request	
    signal f18a_red : std_logic_vector (3 downto 0);
    signal f18a_green : std_logic_vector (3 downto 0);
    signal f18a_blue : std_logic_vector (3 downto 0);
    signal f18a_hsync   : std_logic := '0';
    signal f18a_vsync   : std_logic := '0';
    signal f18a_blank   : std_logic := '0';	

	--hdmi hdlutil signals and types
	signal hdmi2_rgb : std_logic_vector (23 downto 0); --video components
	signal hdmi2_tmds : std_logic_vector (2 downto 0); --hdmi channels
	signal hdmi2_cx : std_logic_vector(9 downto 0);
	signal hdmi2_cy : std_logic_vector(9 downto 0);
    signal hdmi2_video_on : std_logic;
    signal hdmi2_video_hs_n : std_logic;
    signal hdmi2_video_vs_n : std_logic;
    subtype audio_vector is std_logic_vector(15 downto 0);
    type double_audio_vector is array (0 to 1) of audio_vector;	
	signal hdmi2_audio_sample_word : double_audio_vector; --sound
	signal audio_sample : std_logic_vector (15 downto 0);
	signal audio_sample1 : std_logic_vector (15 downto 0);
	signal audio_sample2 : std_logic_vector (15 downto 0);

	--YM2149 PSG signals
	signal psgBc1                        : std_logic:='0'; --psg chip select & mode 1/2
	signal psgBdir : std_logic:='0'; --psg chip select & mode 2/2
	signal psgDataOut : std_logic_vector (7 downto 0); --psg output
	signal psgSound1 : std_logic_vector (7 downto 0); --psg output sound channel 1
	signal psgSound2 : std_logic_vector (7 downto 0) := "10000000"; --psg output sound channel 2
	signal psgSound3 : std_logic_vector (7 downto 0); --psg output sound channel 3
	signal psgPA : std_logic_vector (7 downto 0); --psg port a
	signal psgPB : std_logic_vector (7 downto 0):=x"ff"; --psg port b
	signal psgDebug : std_logic_vector (7 downto 0);


component Gowin_rPLL
    port (
        clkout: out std_logic;
        clkin: in std_logic
    );
end component;

component Gowin_rPLL2
    port (
        clkout: out std_logic;
        clkoutp: out std_logic;
        clkin: in std_logic
    );
end component;

component Gowin_CLKDIV2
    port (
        clkout: out std_logic;
        hclkin: in std_logic;
        resetn: in std_logic
    );
end component;

component Gowin_CLKDIV4
    port (
        clkout: out std_logic;
        hclkin: in std_logic;
        resetn: in std_logic
    );
end component;


component ELVDS_OBUF
    PORT (
    O:OUT std_logic;
    OB:OUT std_logic;
    I:IN std_logic
    );
end component;

component denoise_low
    port (
		data_in		: IN STD_LOGIC;
		clock		: IN STD_LOGIC;
		data_out	: OUT STD_LOGIC 
    );
end component;

component denoise_low8	
	PORT
	(
		data8_in	: IN STD_LOGIC_VECTOR(7 downto 0);
		clock		: IN STD_LOGIC  := '1';
		data8_out	: OUT STD_LOGIC_VECTOR(7 downto 0) 
	);
end component;

component f18a_core
   port (
      clk_100m0_i          : in  std_logic;
      clk_25m0_i           : in  std_logic;

      -- 9918A to Host System Interface
      reset_n_i            : in  std_logic;  -- Must be active for at least one 25MHz clock cycle
      mode_i               : in  std_logic;
      csw_n_i              : in  std_logic;
      csr_n_i              : in  std_logic;
      int_n_o              : out std_logic;
      cd_i                 : in  std_logic_vector(0 to 7);
      cd_o                 : out std_logic_vector(0 to 7);

      -- Video Output
      blank_o              : out std_logic;
      hsync_o              : out std_logic;
      vsync_o              : out std_logic;
      red_o                : out std_logic_vector(0 to 3);
      grn_o                : out std_logic_vector(0 to 3);
      blu_o                : out std_logic_vector(0 to 3);

      -- Feature Selection
      sprite_max_i         : in std_logic;   -- Default sprite max, '0' = 32, '1' = 4
      scanlines_i          : in std_logic;   -- Simulated scan lines, '0' = no, '1' = yes

      -- SPI to GPU
      spi_clk_o            : out std_logic;
      spi_cs_o             : out std_logic;
      spi_mosi_o           : out std_logic;
      spi_miso_i           : in  std_logic
   );
end component;


component hdmi
    generic (VIDEO_ID_CODE : INTEGER; 
            VIDEO_REFRESH_RATE :REAL; 
            AUDIO_RATE :INTEGER; 
            AUDIO_BIT_WIDTH :INTEGER);
      port (
        clk_pixel_x5 : in std_logic;
        clk_pixel : in std_logic;
        clk_audio : in std_logic;
        reset : in std_logic;
        rgb : in std_logic_vector(23 downto 0);
        audio_sample_word : in double_audio_vector;

        tmds: out std_logic_vector(2 downto 0);
        tmds_clock : out std_logic;
    
        cx : out std_logic_vector(9 downto 0);
        cy : out std_logic_vector(9 downto 0); 

        video_on : out std_logic;
        video_hs_n : out std_logic;
        video_vs_n : out std_logic;

        frame_width: out std_logic_vector(9 downto 0);
        frame_height: out std_logic_vector(9 downto 0); 
        screen_width : out std_logic_vector(9 downto 0);
        screen_height: out std_logic_vector(9 downto 0)
      );
end component;

component YM2149 
      port (
      -- data bus
      I_DA                : in  std_logic_vector(7 downto 0);
      O_DA                : out std_logic_vector(7 downto 0);
      O_DA_OE_L           : out std_logic;
      -- control
      I_A9_L              : in  std_logic;
      I_A8                : in  std_logic;
      I_BDIR              : in  std_logic;
      I_BC2               : in  std_logic;
      I_BC1               : in  std_logic;
      I_SEL_L             : in  std_logic;
    
      O_AUDIO             : out std_logic_vector(7 downto 0);
      -- port a
      I_IOA               : in  std_logic_vector(7 downto 0);
      O_IOA               : out std_logic_vector(7 downto 0);
      O_IOA_OE_L          : out std_logic;
      -- port b
      I_IOB               : in  std_logic_vector(7 downto 0);
      O_IOB               : out std_logic_vector(7 downto 0);
      O_IOB_OE_L          : out std_logic;
    
      ENA                 : in  std_logic; -- clock enable for higher speed operation
      RESET_L             : in  std_logic;
      CLK                 : in  std_logic;  -- note 6 Mhz;
      clkHigh             : in std_logic;  --to avoid problems when cpu clk is slower than psg clk
      debug               : out std_logic_vector(7 downto 0)
      );
end component;   
	
begin

-- ____________________________________________________________________________________
-- clock signals

clock1: Gowin_rPLL
    port map (
        clkout => clk_100m,
        clkin => ex_clk_27m
    );

clock2: Gowin_rPLL2
    port map (
        clkout => clk_126m,
        clkoutp => clk_126mn,
        clkin => clk_25m
    );

div2: Gowin_CLKDIV2
    port map (
        clkout => clk_50m,
        hclkin => clk_100m,
        resetn => '1'
    );

div4: Gowin_CLKDIV4
    port map (
        clkout => clk_25m,
        hclkin => clk_100m,
        resetn => '1'
    );

--generated clocks
process (clk_100m)
begin
    if rising_edge(clk_100m) then
        if clk_48k_counter<1042 then
            clk_48k_counter<=clk_48k_counter+1;
        else
            clk_48k_counter<=(others => '0');
            clk_48k<= not clk_48k;
        end if;
        if clk10mCounter<4 then
            clk10mCounter<=clk10mCounter+1;
        else
            clk10mCounter<=(others => '0');
            clk10m<= not clk10m;
        end if;        
    end if;
end process;

process (clk_3m6)
begin
    if rising_edge(clk_3m6) then
        clk_1m8<=not clk_1m8;
    end if;
end process;

-- ____________________________________________________________________________________
-- MEMORY READ/WRITE LOGIC GOES HERE
ioWr_n <= busWr_n or busIorq_n;
memWr_n <= busWr_n or busMreq_n;
ioRd_n <= busRd_n or busIorq_n;
memRd_n <= busRd_n or busMreq_n;



-- ____________________________________________________________________________________
-- BUS ISOLATION GOES HERE
--ex_busDataReverse_n <= '0' when (vdpReq = '1' and ex_busRd_n = '0') else '1';
--ex_busDataOut <= VdpDbi when (ex_busDataReverse_n = '0') else (others => 'Z');



reset <= not (ex_reset_n and busReset_n);
reset_n <= ex_reset_n and busReset_n;


--F18A VDP and signals
f18a_csw_n<= '0' when busAddress (7 downto 2) = "100110" and (ioWr_n='0') else '1'; -- I/O:98-99h / VDP(TMS9918A)
f18a_csr_n<= '0' when busAddress (7 downto 2) = "100110" and (ioRd_n='0') else '1'; -- I/O:98-99h / VDP(TMS9918A)

vdp2 : f18a_core
   port map (
      clk_100m0_i    => clk_50m,   -- in  std_logic;
      clk_25m0_i     => clk_25m,    -- in  std_logic;
      reset_n_i      => reset_n,     -- in  std_logic;
      mode_i         => busAddress(0),      -- in  std_logic;
      csw_n_i        => f18a_csw_n,     -- in  std_logic;
      csr_n_i        => f18a_csr_n,     -- in  std_logic;
      int_n_o        => open,     -- out std_logic;
      cd_i           => busDataOut,        -- in  std_logic_vector(0 to 7);
      cd_o           => open,      -- out std_logic_vector(0 to 7);
      blank_o        => f18a_blank,     -- out std_logic;
      hsync_o        => f18a_hsync,     -- out std_logic;
      vsync_o        => f18a_vsync,     -- out std_logic;
      red_o          => f18a_red,       -- out std_logic_vector(0 to 3);
      grn_o          => f18a_green,       -- out std_logic_vector(0 to 3);
      blu_o          => f18a_blue,       -- out std_logic_vector(0 to 3);
      sprite_max_i   => '1',      -- in std_logic;   -- Default sprite max, '0' = 32, '1' = 4
      scanlines_i    => '0',      -- in std_logic;   -- Simulated scan lines, '0' = no, '1' = yes
      spi_clk_o      => open,   -- out std_logic;
      spi_cs_o       => open,    -- out std_logic;
      spi_mosi_o     => open,  -- out std_logic;
      spi_miso_i     => '1'   -- in  std_logic
   );


--HDMI hdlutil extension and signals
hdmi2_rgb <= f18a_red & "0000" & f18a_green & "0000" & f18a_blue & "0000";
audio_sample1 <= "000" & psgSound1 & "00000";
audio_sample2 <= "000" & psgSound1 & "00000";
audio_sample <= audio_sample1 + audio_sample2;
hdmi2_audio_sample_word <= (audio_sample, audio_sample);

hdmi2 : hdmi
    generic map(VIDEO_ID_CODE => 1, 
        VIDEO_REFRESH_RATE => 60.0, 
        AUDIO_RATE => 48000, 
        AUDIO_BIT_WIDTH => 16)
    port map(
        clk_pixel_x5  => clk_126m,
        clk_pixel => clk_25m,
        clk_audio => clk_48k,
        reset => reset,
        rgb => hdmi2_rgb,
        audio_sample_word => hdmi2_audio_sample_word,

        tmds => hdmi2_tmds,
        tmds_clock => open,
    
        cx => hdmi2_cx,
        cy => hdmi2_cy,

        video_on => hdmi2_video_on,
        video_hs_n => hdmi2_video_hs_n,
        video_vs_n => hdmi2_video_vs_n,

        frame_width => open,
        frame_height => open,
        screen_width => open,
        screen_height => open        
    );
OBUFDS_blue  : ELVDS_OBUF port map ( O  => data_p(0), OB => data_n(0), I  => hdmi2_tmds(0)  );
OBUFDS_red   : ELVDS_OBUF port map ( O  => data_p(1), OB => data_n(1), I  => hdmi2_tmds(1) );
OBUFDS_green : ELVDS_OBUF port map ( O  => data_p(2), OB => data_n(2), I  => hdmi2_tmds(2)   );
OBUFDS_clock : ELVDS_OBUF port map ( O  => clk_p, OB => clk_n, I  => clk_25m );       


--YM219 PSG and signals
psgBdir <= '1' when busAddress (7 downto 3) = "10100" and (ioWr_n='0') and busAddress(1)='0' else '0'; -- I/O:A0-A2h / PSG(AY-3-8910) bdir = 1 when writing to &HA0-&Ha1
psgBc1 <= '1' when busAddress (7 downto 3) = "10100" and ((ioRd_n='0' and busAddress(1)='1') or (busAddress(1)='0' and ioWr_n='0' and busAddress(0)='0')) else '0'; -- I/O:A0-A2h / PSG(AY-3-8910) bc1 = 1 when writing A0 or reading A2
psgPA<=(others=>'0');

psg1: YM2149
    port map (
        -- data bus
        I_DA        => busDataOut,
        O_DA        => psgDataOut,
        O_DA_OE_L   => open,
        -- control
        I_A9_L      => '0',
        I_A8        => '1',
        I_BDIR      => psgBdir,
        I_BC2       => '1',
        I_BC1       => psgBc1,
        I_SEL_L     => '1',
        
        O_AUDIO     => psgSound1,
        -- port a
        I_IOA       => psgPA,
        O_IOA       => open,
        O_IOA_OE_L  => open,
        -- port b
        I_IOB       => psgPB,
        O_IOB       => psgPB,
        O_IOB_OE_L  => open,
        
        ENA         => '1', -- clock enable for higher speed operation
        RESET_L     => busReset_n,
        CLK         => clk_1m8,
        clkHigh     => clk_50m,
        debug       => psgDebug
    );


denoise1: denoise_low
	port map (
		data_in => ex_busMreq_n,
		clock => clk_50m,
		data_out => busMreq_n
	);

denoise2: denoise_low
	port map (
		data_in => ex_busIorq_n,
		clock => clk_50m,
		data_out => busIorq_n
	);

denoise3: denoise_low
	port map (
		data_in => ex_busRd_n,
		clock => clk_50m,
		data_out => busRd_n
	);

denoise4: denoise_low
	port map (
		data_in => ex_busWr_n,
		clock => clk_50m,
		data_out => busWr_n
	);

denoise5: denoise_low
	port map (
		data_in => ex_busReset_n,
		clock => clk_50m,
		data_out => busReset_n
	);

denoise6: denoise_low
	port map (
		data_in => ex_clk_3m6,
		clock => clk_50m,
		data_out => clk_3m6
	);

denoise8_1: denoise_low8
    port map (
		data8_in    => ex_busAddress,
		clock		=> clk_50m,
		data8_out	=> busAddress
    );

denoise8_2: denoise_low8
    port map (
		data8_in    => ex_busDataOut,
		clock		=> clk_50m,
		data8_out	=> busDataOut
    );

ex_led <= not psgDebug(5 downto 0);


end;
