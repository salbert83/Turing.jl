using Turing
using HDF5, JLD
using Gadfly
using Mamba: summarystats
using DataFrames

make_sample_plot(EXPPATH, chain, val_name, dim) = begin
  val_vec = chain[Symbol("$val_name")]
  val_dim = map(p_1 -> p_1[1], val_vec)

  val_name_simple = replace(val_name, r"\[|\]", "")
  val_dim_traj_p = plot(x=1:length(val_dim), y=val_dim,
                        Guide.xlabel("Number of iterations"),
                        Guide.ylabel("Value of $val_name_simple-$dim"),
                        Guide.title("Traj. Plot for $val_name_simple-$dim"),
                        Geom.line)

  draw(PNG(EXPPATH*"/$val_name_simple-$dim-traj_p.png", 8inch, 4.5inch), val_dim_traj_p)

  val_dim_density = plot(x=val_dim,
                         Guide.xlabel("Number of iterations"),
                         Guide.ylabel("Value of $val_name_simple-$dim"),
                         Guide.title("Density Plot for $val_name_simple-$dim"),
                         Geom.density)

  draw(PNG(EXPPATH*"/$val_name_simple-$dim-density.png", 8inch, 4.5inch), val_dim_density)
end

N = 1000
col = true
MODELNAME = "LDA"

spl_colors = [colorant"#16a085", colorant"#8e44ad", colorant"#7f8c8d", colorant"#c0392b"]

TPATH = Pkg.dir("Turing")
MODELPATH = MODELNAME == "HMM" ? TPATH*"/nips-2017/hmm" :
                                 TPATH*"/nips-2017"

spl_names = col? ["HMC($N,0.05,6)",
                  "HMCDA($N,200,0.65,0.35)",
                  "NUTS($N,200,0.65)",
                  "PG(50,$N)"] :
                 ["Gibbs($N,PG(50,1,:y),HMC(1,0.25,6,:phi,:theta))",
                  "Gibbs($N,PG(50,1,:y),HMCDA(1,200,0.65,0.75,:phi,:theta))",
                  "Gibbs($N,PG(50,1,:y),NUTS(1,200,0.65,:phi,:theta))",
                  "PG(50,$N)"]

spl_names_short = col? ["HMC",
                        "HMCDA",
                        "NUTS",
                        "PG_col"] :
                       ["Gibbs-PG-HMC",
                        "Gibbs-PG-HMCDA",
                        "Gibbs-PG-NUTS",
                        "PG_uncol"]

chain = nothing

lyrs = []
spl_name_arr = []
time_elpased_arr = []
min_ess_arr = []
max_ess_arr = []
min_mcse_arr = []
max_mcse_arr = []


for i = 1:4

  spl_name = spl_names[i]; push!(spl_name_arr, spl_name)

  # Load chain and gen summary
  if MODELNAME == "HMM"
    chain = col? load(MODELPATH*"/hmm-collapsed-$spl_name-chain.jld")["chain"] :
                 load(MODELPATH*"/hmm-uncollapsed-$spl_name-chain.jld")["chain"]
  else
    chain = col? load(MODELPATH*"/lda-exps-chain-$i.jld")["chain"] :
                 load(MODELPATH*"/lda-exps-chain-$i-un.jld")["chain"]
  end
  smr = summarystats(chain)

  # Create path if not exist
  EXPPATH = MODELPATH*"/plots/$(spl_names_short[i])"
  ispath(EXPPATH) || mkdir(EXPPATH)

  # Write summary to file
  open(EXPPATH*"/smr.txt", "w") do f
    write(f, string(smr))
  end

  # Get min/max ess/mcse
  ess_idx = findfirst(smr.colnames, "ESS")
  min_ess = min(smr.value[:,ess_idx,1]...); push!(min_ess_arr, min_ess)
  max_ess = max(smr.value[:,ess_idx,1]...); push!(max_ess_arr, max_ess)

  mcse_idx = findfirst(smr.colnames, "MCSE")
  min_mcse = min(smr.value[:,mcse_idx,1]...); push!(min_mcse_arr, min_mcse)
  max_mcse = max(smr.value[:,mcse_idx,1]...); push!(max_mcse_arr, max_mcse)

  # Get time elapsed
  time_elpased = sum(chain[:elapsed]); push!(time_elpased_arr, time_elpased)

  # Traj of some samples
  make_sample_plot(EXPPATH, chain, "phi[1]", 1)
  make_sample_plot(EXPPATH, chain, "phi[1]", 2)
  make_sample_plot(EXPPATH, chain, "phi[2]", 1)
  make_sample_plot(EXPPATH, chain, "phi[2]", 2)
  make_sample_plot(EXPPATH, chain, "theta[1]", 1)
  make_sample_plot(EXPPATH, chain, "theta[1]", 2)
  make_sample_plot(EXPPATH, chain, "theta[2]", 1)
  make_sample_plot(EXPPATH, chain, "theta[2]", 2)

  # Get lps
  lps = chain[:lp]

  # For plotting pls together
  lyr = layer(x=1:length(lps), y=-lps, Geom.line, Theme(default_color=spl_colors[i]))
  push!(lyrs, lyr)

end

EXPPATH = MODELPATH*"/plots/"
ispath(EXPPATH) || mkdir(EXPPATH)

lps_p = plot(lyrs[1:3]...,
             Guide.xlabel("Number of iterations"), Guide.ylabel("Negative log-posterior"),
             Guide.title("Negative Log-posterior for the $MODELNAME Model"),
             Guide.manual_color_key("Legend", spl_names[1:3], spl_colors[1:3])
        )

# Gen summary table
iscol = col ? "col" : "uncol"

df = DataFrame(Sampler = spl_name_arr, Time_elpased = time_elpased_arr, Min_ESS = min_ess_arr, Max_ESS = max_ess_arr, Min_MCSE = min_mcse_arr, Max_MCSE = max_mcse_arr)
writetable(EXPPATH*"/$iscol-stats-table.csv", df)

draw(PNG(EXPPATH*"/$iscol-lps.png", 8inch, 4.5inch), lps_p)