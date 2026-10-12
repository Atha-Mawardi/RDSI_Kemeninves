
###------------------------------------------------------###
### 02. IRIO updating                                    ###
### performing RAS to update the technical coefficients. ###
###------------------------------------------------------###

#-> Import library
library(rio)
library(openxlsx)
library(dplyr)
library(tidyverse)

#-> Import data
pdrb <- openxlsx::read.xlsx("01 Data/IO-IRIO-NA/processed/updating_masukan/regional gdp 52 subsectors_1624.xlsx",sheet = "main_dat")
irio_raw <- rio::import("01 Data/IO-IRIO-NA/processed/updating_masukan/irio16.csv",header = T)

#-> Data prep
pdrb <- pdrb %>% filter(!is.na(kodeIO))
pdrb <- pdrb %>% select(., c(kode,upd))
pdrb_adj <- irio_raw %>% select(., c(kode)) %>% inner_join(.,pdrb,by=c("kode"))

irio <- irio_raw
rn <- irio_raw$kode
rownames(irio) <- rn
irio <- irio %>% dplyr::select(., -c(kode))


### <------- IRIO update
### Prep IRIO data
# <- Z matrix
zmatr <- irio[,c(1:1768)][c(1:1768),]
zmatr <- as.matrix(sapply(zmatr, as.numeric))
zmatr <- (zmatr * 1e6) + 1/1768

# <- Total Output and Total Input (X)
totaloutput <- irio[c(1:1768),][,1780]
totaloutput <- (totaloutput * 1e6) + 1

totalinput <- irio[,c(1:1768)][1777,]
totalinput <- matrix(as.numeric(unlist(totalinput)),nrow=nrow(totalinput))
totalinput <- (totalinput * 1e6) + 1

# <- Total Intermediate Input (U) and Intermediate Output (V)
intinp_hor <- colSums(zmatr)
intout_ver <- rowSums(zmatr)

# <- Technology Matrix (A Matrix) z_i/U
amatr <- sweep(zmatr, 2, totaloutput, "/")

# <- Update vector
update1624 <- pdrb_adj$upd

### RAS Update
# <- U = Total Intermediate Output
intout_ver_up <- intout_ver*update1624
tot_intout_ver_up <- sum(intout_ver_up)

# <- V = Total Intermediate Input
intinp_hor_up <- intinp_hor*update1624
tot_intinp_hor_up <- sum(intinp_hor_up)

intinp_hor_up2 <- intinp_hor_up/tot_intinp_hor_up
intinp_hor_up <- intinp_hor_up2*tot_intout_ver_up

# <- X = Total Output
totaloutput_up <- totaloutput*update1624

# <- RAS Update func
x1 <- as.matrix(totaloutput_up)
u1 <- as.matrix(intout_ver_up)
v1 <- as.matrix(intinp_hor_up)
A <- amatr

# <- sectors where RAS is mathematically defined
idx_pos <- which(x1 > 0 & u1 > 0 & v1 > 0)

A_seed <- A

# <- sectors active in 2024 but structurally empty in base year
new_sectors <- which(x1 > 0 & colSums(A) == 0)

if (length(new_sectors) > 0) {
  ref_structure <- colMeans(A[, idx_pos, drop = FALSE])
  
  for (j in new_sectors) {
    A_seed[, j] <- 0.01 * ref_structure   # structural prior, not numeric hack
  }
}

A_sub <- A_seed[idx_pos, idx_pos, drop = FALSE]
x_sub <- x1[idx_pos, , drop = FALSE]
u_sub <- u1[idx_pos, , drop = FALSE]
v_sub <- v1[idx_pos, , drop = FALSE]

maxiter <- 10000
tol <- 1e-10

for (iter in 1:maxiter) {
  
  ## ---- Row scaling (match u) ----
  u_hat <- A_sub %*% x_sub
  
  # proteksi numerik
  u_hat[u_hat == 0] <- 1
  
  r <- as.vector(u_sub / u_hat)
  R <- diag(r)
  
  A1 <- R %*% A_sub
  
  ## ---- Column scaling (match v) ----
  v_hat <- colSums(
    A1 * matrix(x_sub,
                nrow = nrow(A1),
                ncol = ncol(A1),
                byrow = TRUE)
  )
  
  # proteksi numerik
  v_hat[v_hat == 0] <- 1
  
  s <- as.vector(v_sub / v_hat)
  S <- diag(s)
  
  A_new <- A1 %*% S
  ## ---- Constraint-based convergence check ----
  row_err <- max(abs(A_new %*% x_sub - u_sub) / u_sub)
  col_err <- max(
    abs(
      colSums(
        A_new * matrix(x_sub,
                       nrow = nrow(A_new),
                       ncol = ncol(A_new),
                       byrow = TRUE)
      ) - v_sub
    ) / v_sub
  )
  if (row_err < tol && col_err < tol) break
  A_sub <- A_new
}

A_IRIO_2024 <- matrix(0, nrow = nrow(A), ncol = ncol(A))
A_IRIO_2024[idx_pos, idx_pos] <- A_sub


# <- res eval
evaluate <- data.frame("row_consistency" = max(abs(A_IRIO_2024 %*% x1 - u1)),
                       "column_consistency" = max(abs(colSums(A_IRIO_2024 * matrix(x1, nrow=nrow(A_IRIO_2024), 
                                                                                   ncol=ncol(A_IRIO_2024), byrow=TRUE)) - v1)))

matlist <- list("a_irio_2024" = A_IRIO_2024,
                "a_irio_2016" = amatr,
                "interm_input_2024" = intinp_hor_up,
                "interm_output_2024" = intout_ver_up,
                "totaloutput_2024" = totaloutput_up,
                "matr eval" = evaluate)

openxlsx::write.xlsx(matlist,"01 Data/IO-IRIO-NA/output/updating_2024/v1_irio_2024(52x52).xlsx")
