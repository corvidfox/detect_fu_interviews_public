# Create a data frame with two variables: 
# - The final abuse determination made by the LEAD panel and;
# - The abuse determination made using the DETECT tool at the initial visit

# This data frame will be used to create a confusion matrix for the LEAD panel assessment master table site.

# Required libraries: tidyverse, flextable

compare_det <- function(lead_final_det, detect_tool, abuse_type){
  
  
  # Select the specific abuse column from the final determination dataframe
  abuse_final_det <- lead_final_det %>% select(medstar_id, {{abuse_type}}) %>%
    
    # convert  Yes/ No factor abuse determination variable to Positive/ Negative variable
    mutate(
      abuse_item_chr :=  case_when(
        {{abuse_type}} == "Yes" ~ "positive",
        {{abuse_type}} == "No"  ~ "negative"
      ),
      "{{abuse_type}}_pn" := factor(abuse_item_chr, levels = c("positive", "negative"))
    )
  
  # Determine the initial MedStar Medic DETECT tool abuse determination (counts as positive if at least one of the items in the DETECT tool was positive)
  detect_tool <- detect_tool %>% 
    mutate(
      # Create a column that has a value of "positive" if at least one of the items in the DETECT tool variables are positive
      detect_tool_det = case_when(
        if_any(ends_with("_5cat_f"), ~. == "Yes")  ~ "positive",
        if_all(ends_with("_5cat_f"), ~. == "No")   ~ "negative",
        TRUE                                       ~ NA
      ),
      # Convert variable type to factor
      detect_tool_det = factor(detect_tool_det, levels = c("positive", "negative"))
    )
  
  # Combine the two variables into one df
  tool_vs_lead <- abuse_final_det %>% left_join(detect_tool, by = "medstar_id")
  
  # Name of lead abuse determination variable
  lead_abuse <- tool_vs_lead %>% select(ends_with("_pn")) %>% names()
 
  # Create contingency table
  conf_con <- tool_vs_lead %>% select({lead_abuse}, detect_tool_det) %>% drop_na() %>% table(dnn = c(lead_abuse, "detect_tool_det")) %>% as.data.frame()
  
   
  # Create a frequency data frame with columns structured appropriately for flextable
    
  col_1_label <- c("positive", "negative", "Total")
  col_2_actual_positive <- c(conf_con$Freq[conf_con[[lead_abuse]] == "positive" & conf_con$detect_tool_det == "positive"], 
                             conf_con$Freq[conf_con[[lead_abuse]] == "positive" & conf_con$detect_tool_det == "negative"],
                             sum(conf_con$Freq[conf_con[[lead_abuse]] == "positive"]))
  col_3_actual_negative <- c(conf_con$Freq[conf_con[[lead_abuse]] == "negative" & conf_con$detect_tool_det == "positive"], 
                             conf_con$Freq[conf_con[[lead_abuse]] == "negative" & conf_con$detect_tool_det == "negative"],
                             sum(conf_con$Freq[conf_con[[lead_abuse]] == "negative"]))
  col_4_total <- c(sum(conf_con$Freq[conf_con$detect_tool_det == "positive"]), sum(conf_con$Freq[conf_con$detect_tool_det == "negative"]), sum(conf_con$Freq)) 
  
  con_flex <- data.frame(col_1_label, col_2_actual_positive, col_3_actual_negative, col_4_total) %>%
  
    # Convert to flextable and format flextable
    flextable() %>%
    # Format flextable
    set_header_labels(
      col_1_label = "Detect Tool",
      col_2_actual_positive = "positive",
      col_3_actual_negative = "negative",
      col_4_total = "Total"
    )%>%
    border_remove() %>%
    bg(part = "body", i = 1, j = 2, bg = "#8cc0ae") %>%
    bg(part = "body", i = 2, j = 3, bg = "#8cc0ae") %>%
    bg(part = "body", i = 2, j = 2, bg = "#9dcfbc") %>%
    bg(part = "body", i = 1, j = 3, bg = "#9dcfbc") %>%
    color(j = c(2,3), i = c(1,2), color = "white") %>%
    bold(j = 1, part = "header") %>%
    bold(i = 1, j = 1, part = "header") %>%  
    height(i = c(1,2), height = 1.5, unit = "in") %>%
    hrule(rule = "exact") %>%
    width(j = -c(1,4), width = 1.5, unit = "in") %>%
    width(j = 1, width = 1) %>%
    align(align = "center") %>%
    align(j = 1, align = "right") %>%
    align(j = 4, align = "left", part = c("body")) %>%
    align(j = 4, align = "left", part = c("header")) %>%
    valign(valign = c("center")) %>%
    vline(j = 3, border = fp_border(color = "black")) %>%
    hline(i = 2, border = fp_border(color = "black")) %>%
    add_header_lines("LEAD Panel Assessment") %>%
    align(i = 1, align = "center", part = "header") %>%
    align(i = 2, j = c(1,2,3), align = "center", part = "header")
  
  # Lead abuse determination vector
  lead_abuse_vector <- conf_con[[lead_abuse]]
  
  # Create table with specificity, sensitivity and prevalence
  conf_calc <- conf_con %>%
    summarise(
      Sensitivity = paste0(format(round((Freq[lead_abuse_vector == "positive" & detect_tool_det == "positive"]/sum(Freq[lead_abuse_vector == "positive"]))*100,
                                        digits = 2), nsmall = 2), " %"),
      Specificity = paste0(format(round((Freq[lead_abuse_vector == "negative" & detect_tool_det == "negative"]/sum(Freq[lead_abuse_vector == "negative"]))*100,
                                        digits = 2), nsmall = 2), " %"),
      Prevalence = paste0(format(round((sum(Freq[lead_abuse_vector == "positive"])/sum(Freq))*100, digits = 2), nsmall = 2), " %")
      
    ) %>% t() %>% as.data.frame() %>% rownames_to_column() %>% 
    flextable() %>%
    delete_part(part = "header") %>%
    hline_top() %>%
    hline_bottom() %>%
    bold(j = 1) %>%
    width(width = 1, unit = "in")
  
  out <- list(con_flex, conf_calc, tool_vs_lead)              # Store output in list
  return(out)
}