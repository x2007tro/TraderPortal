lib <- c("shiny","DT","ggplot2")
lapply(lib, function(x){library(x, character.only = TRUE)})
setwd("C:/Users/KE/OneDrive/Development/Shiny/Practice 1/")
source("utility.R")

#
# Portfolio refresh time
#
refresh_time <- 60000
blotter_size_tracker <- 1
message_count_trader <- 1

#
# Shiny server
#
server <- function(input, output, session) {
  
  #
  # Update section portfolio
  #
  autoUpdate <- reactiveTimer(refresh_time)
  
  port_info <- reactive({
    autoUpdate()
    port_info <- UtilGetPortfolio()
  })
  
  output$last_update_time <- renderText({
    update_datetime <- port_info()$update_datetime
    paste0("Last updated: ", format(update_datetime, "%Y-%m-%d %H:%M:%S"))
  })

  output$portfolio_dt <- DT::renderDataTable({
    DT::datatable(port_info()$portfolio, options = list(pageLength = 10,
                                                      orderClasses = TRUE,
                                                      searching = FALSE,
                                                      paging = TRUE))
  })

  observe({
    updateSelectInput(session, "add_trade_list", choices = port_info()$holdings)
  })
  
  #
  # Handle add to trade list
  #
  observeEvent(input$add_trade_list_submit, {
    blotter_size_tracker <<- blotter_size_tracker + 1
    
    holdings <- port_info()$portfolio
    trade_item <- holdings[holdings$Ticker == input$add_trade_list,]
    ticker_w_crncy <- trade_item[1,"Ticker"]
    pos <- regexpr("-", ticker_w_crncy)[1]
    ticker <- substr(ticker_w_crncy, 1, pos-1)
    currency <- substr(ticker_w_crncy, pos+1, nchar(ticker_w_crncy))
    security_type <- trade_item[1,"SecurityType"]
    position <- trade_item[1,"Position"]
    
    output[[paste0('trade_item', blotter_size_tracker)]] <- renderUI({
      list(
        br(),
        tags$div(class = "blotter_fields", textInput(paste0('ticker',blotter_size_tracker), NULL, value = ticker, width = blotter_field_default_width)),
        tags$div(class = "blotter_fields", selectInput(paste0('currency',blotter_size_tracker), NULL, choices = c("CAD","USD"), selected = currency, width = blotter_field_default_width)),
        tags$div(class = "blotter_fields", selectInput(paste0('side',blotter_size_tracker), NULL, choices = c("Buy", "Sell"), selected = "Sell", width = blotter_field_default_width)),
        tags$div(class = "blotter_fields", numericInput(paste0('shares',blotter_size_tracker), NULL, value = position, min = 0, max = 1000,  width = blotter_field_default_width)),
        tags$div(class = "blotter_fields", selectInput(paste0('type',blotter_size_tracker), NULL, choices = c("Market", "Limit"), width = blotter_field_default_width)),
        tags$div(class = "blotter_fields", numericInput(paste0('limit_price',blotter_size_tracker), NULL, value = 0, min = 0, max = 1000,  width = blotter_field_default_width)),
        tags$div(class = "blotter_fields", numericInput(paste0('trade_value',blotter_size_tracker), NULL, value = 0, min = 0, max = 1000,  width = blotter_field_default_width)),
        tags$div(class = "blotter_fields", checkboxInput(paste0('transmit',blotter_size_tracker), NULL, value = TRUE, width = blotter_field_default_width)),
        tags$div(class = "blotter_fields", actionButton(paste0('trade',blotter_size_tracker), "Trade", width = blotter_field_default_width))
        #br()
      )
    })
  })
  
  #
  # Market ETFs performance
  #
  mkt_etfs <- UtilGetMarketReturn()
  output$equity_mkt <- renderPlot({
    UtilPlotMarketReturn(mkt_etfs, "Equity", input$eq_perf_period)
  })
  
  output$tbond_mkt <- renderPlot({
    UtilPlotMarketReturn(mkt_etfs, "Tbond", input$tb_perf_period)
  })
  
  output$cbond_mkt <- renderPlot({
    UtilPlotMarketReturn(mkt_etfs, "Cbond", input$cb_perf_period)
  })
  
  #
  # Handling dynamic trade items 
  #
  observeEvent(input$blotter_size_selector,{
    #
    # Clear current value
    #
    print(blotter_size_tracker)
    lapply(1:blotter_size_tracker, function(i){
      output[[paste0('trade_item',i)]] <- renderUI({
        tags$div()
      })
    })
    
    #
    # Update new value
    # 
    blotter_size_tracker <<- as.numeric(input$blotter_size_selector)
    lapply(1:blotter_size_tracker, function(i){
      output[[paste0('trade_item',i)]] <- renderUI({
        list(
          br(),
          tags$div(class = "blotter_fields", textInput(paste0('ticker',i), NULL, value = "", width = blotter_field_default_width, placeholder = "i.e. AAPL-USD")),
          tags$div(class = "blotter_fields", selectInput(paste0('currency',i), NULL, choices = c("CAD","USD"), width = blotter_field_default_width)),
          tags$div(class = "blotter_fields", selectInput(paste0('side',i), NULL, choices = c("Buy", "Sell"), width = blotter_field_default_width)),
          tags$div(class = "blotter_fields", numericInput(paste0('shares',i), NULL, value = 0, min = 0, max = 1000,  width = blotter_field_default_width)),
          tags$div(class = "blotter_fields", selectInput(paste0('type',i), NULL, choices = c("Market", "Limit"), width = blotter_field_default_width)),
          tags$div(class = "blotter_fields", numericInput(paste0('limit_price',i), NULL, value = 0, min = 0, max = 1000,  width = blotter_field_default_width)),
          tags$div(class = "blotter_fields", numericInput(paste0('trade_value',i), NULL, value = 0, min = 0, max = 1000,  width = blotter_field_default_width)),
          tags$div(class = "blotter_fields", checkboxInput(paste0('transmit',i), NULL, value = FALSE, width = blotter_field_default_width)),
          tags$div(class = "blotter_fields", actionButton(paste0('trade',i), "Trade", width = blotter_field_default_width))
          #br()
        )
      })
    })
  })
  
  #
  # Handling trade order submit
  #
  lapply(1:max_blotter_size, function(i){
    observeEvent(input[[paste0("trade",i)]],{

	  blotter <- data.frame(LocalTicker = input[[paste0('ticker',i)]],
							Action = input[[paste0('side',i)]],
							Quantity = input[[paste0('shares',i)]],
							OrderType = input[[paste0('type',i)],
							LimitPrice = input[[paste0('limit_price',i)]],
							SecurityType = "Stk",
							Currency = input[[paste0('currency',i)]],
							TradeSwitch = input[[paste0('transmit',i)]],
							StringsAsFactors = FALSE)
	  
	  res <- UtilTradeWithIB(blotter)
      msg <- res$msg_rec
      trd <- res$trade_rec
	  
	  load("history.RData")
	  messages <- rbind(messages, msg)
	  trades <- rbind(trades, trd)
	  save(messages, trades, file="history.RData")
	  
      msg_id <- message_count_trader %% max_message_count
      output[[paste0('message', msg_id)]] <- renderText({
        msg
      })
      message_count_trader <<- message_count_trader + 1 
    })
  })
  
  #
  # handling watchlist request
  #
  observeEvent(input$ticker_search_submit, {
    tik <- isolate(input$ticker_search)
    output$prev_day_quote <- renderText({
      prc <- UtilGetStockLastestPrice(tik)
      opt <- paste0(c("Date", colnames(prc)), ": ", 
                     c(format(index(prc)[1], "%Y-%m-%d"), round(prc[1,],2)))
    })
    
    output$hist_return <- renderPlot({
      hist_ret <- UtilGetStockHistReturn(tik)
      UtilPlotMarketReturn(hist_ret, input$ticker_search, "1Y")
    })
  })
  
}