/*
Copyright (c) 2013, Dust Networks.  All rights reserved.
Modified by RE:NAK 2017.5.24
*/

#include "dn_common.h"
#include "string.h"
#include "stdio.h"
#include "cli_task.h"
#include "loc_task.h"
#include "dn_system.h"
#include "dn_i2c.h"
#include "dn_exe_hdr.h"
#include "app_task_cfg.h"
#include "Ver.h"

#include "dnm_ucli.h"


//=========================== definitions =====================================

#define I2C_SLAVE_ADDR       0x66
#define I2C_PAYLOAD_LENGTH   32


//=========================== variables =======================================

typedef struct {
   dn_ioctl_i2c_transfer_t   i2cTransfer;
   OS_STK                    i2cTaskStack[TASK_APP_I2C_STK_SIZE];
   INT8U                     i2cBuffer[I2C_PAYLOAD_LENGTH];
} i2c_app_vars_t;

i2c_app_vars_t     i2c_app_v;

//=========================== prototypes ======================================

static void i2cTask(void* unused);

//===== CLI handlers
dn_error_t    cli_writeAddrCmdHandler( char const* arg, INT32U len);
dn_error_t    cli_writeDataCmdHandler( char const* arg, INT32U len);
dn_error_t    cli_readDataCmdHandler(  char const* arg, INT32U len);
dn_error_t    cli_resetCmdHandler(     char const* arg, INT32U len);

//=========================== const ===========================================

//===== CLI

const dnm_ucli_cmdDef_t cliCmdDefs[] = {
   {&cli_writeAddrCmdHandler,  "wraddr",      "",       DN_CLI_ACCESS_LOGIN},
   {&cli_writeDataCmdHandler,  "wrdata",      "",       DN_CLI_ACCESS_LOGIN},
   {&cli_readDataCmdHandler,  "rddata",      "",       DN_CLI_ACCESS_LOGIN},
   {&cli_resetCmdHandler,    "reset",       "",      DN_CLI_ACCESS_LOGIN},
   {NULL,                    NULL,         NULL,     DN_CLI_ACCESS_NONE},
};


//=========================== initialization ==================================

/**
\brief This is the entry point in the application code.
*/
int p2_init(void) {
   INT8U                   osErr;

   cli_task_init(
      "I2C MANUAL TEST",                    // appName
       cliCmdDefs                           // cliCmds
   );
   loc_task_init(
      JOIN_NO,                              // fJoin
      NETID_NONE,                           // netId
      UDPPORT_NONE,                         // udpPort
      NULL,                                 // joinedSem
      BANDWIDTH_NONE,                       // bandwidth
      //NULL,                                 // serviceSem
      NULL
   );
   
   // create the I2C task
   osErr  = OSTaskCreateExt(
      i2cTask,
      (void *)0,
      (OS_STK*)(&i2c_app_v.i2cTaskStack[TASK_APP_I2C_STK_SIZE-1]),
      TASK_APP_I2C_PRIORITY,
      TASK_APP_I2C_PRIORITY,
      (OS_STK*)i2c_app_v.i2cTaskStack,
      TASK_APP_I2C_STK_SIZE,
      (void *)0,
      OS_TASK_OPT_STK_CHK | OS_TASK_OPT_STK_CLR
   );
   ASSERT(osErr==OS_ERR_NONE);
   OSTaskNameSet(TASK_APP_I2C_PRIORITY, (INT8U*)TASK_APP_I2C_NAME, &osErr);
   ASSERT(osErr==OS_ERR_NONE);
   
   return 0;
}

//=========================== I2C task ========================================

/**
\brief A demo task to show the use of the I2C.
*/
static void i2cTask(void* unused) {
   dn_error_t                     dnErr;
   dn_i2c_open_args_t             i2cOpenArgs;
   
   
   //===== open the I2C device
   
   // wait a bit
   OSTimeDly(1000);
   
   // open the I2C device
   //i2cOpenArgs.frequency = DN_I2C_FREQ_184_KHZ;
   //i2cOpenArgs.frequency = DN_I2C_FREQ_123_KHZ;
   i2cOpenArgs.frequency = DN_I2C_FREQ_92_KHZ;
   dnErr = dn_open(
      DN_I2C_DEV_ID,
      &i2cOpenArgs,
      sizeof(i2cOpenArgs)
   );
   ASSERT(dnErr==DN_ERR_NONE); 
   
   // prepare buffer
   memset(i2c_app_v.i2cBuffer,0,sizeof(i2c_app_v.i2cBuffer));
   
   // initialize I2C communication parameters   
   i2c_app_v.i2cTransfer.slaveAddress    = I2C_SLAVE_ADDR;   
   i2c_app_v.i2cTransfer.writeBuf        = NULL;   
   i2c_app_v.i2cTransfer.readBuf         = i2c_app_v.i2cBuffer;   
   i2c_app_v.i2cTransfer.writeLen        = 0;   
   i2c_app_v.i2cTransfer.readLen         = 2;   
   i2c_app_v.i2cTransfer.timeout         = 0xff;   
   
   while(1) { // this is a task, it executes forever
      
      dnm_ucli_printf("I2C Manual Test\r\n");
      
      // wait for next cycle
      OSTimeDly(60000);      
      
   }
}


//===== 'wrData' (Write to Registor) CLI command

dn_error_t cli_writeDataCmdHandler(char const* arg, INT32U len) {
   dn_error_t     dnErr;
   INT8U          i;
   int            l;
   int            dtlen;


   //--- param 
   l = sscanf (arg, "%02x", &dtlen);
   if (l < 1) {
      dnm_ucli_printf("!!! Usage !!!\r\n");
      dnm_ucli_printf("wraddr write_Len\r\n");
      return DN_ERR_INVALID;
   }
   else {
   // set bytes to send
   for (i=0;i<dtlen;i++) {
      i2c_app_v.i2cBuffer[i] = i;
   }
   // initialize I2C communication parameters
   //i2c_app_v.i2cTransfer.slaveAddress    = saddr;
   i2c_app_v.i2cTransfer.writeBuf        = i2c_app_v.i2cBuffer;
   i2c_app_v.i2cTransfer.readBuf         = NULL;
   i2c_app_v.i2cTransfer.writeLen        = dtlen;
   i2c_app_v.i2cTransfer.readLen         = 0;
   i2c_app_v.i2cTransfer.timeout         = 0xff;

   // initiate transaction
   dnErr = dn_ioctl(
      DN_I2C_DEV_ID,
      DN_IOCTL_I2C_TRANSFER,
      &i2c_app_v.i2cTransfer,
      sizeof(i2c_app_v.i2cTransfer)
   );
   return DN_ERR_NONE;
   }
}



//===== 'wrAddr' (I2C Slave Address Write) CLI command

dn_error_t cli_writeAddrCmdHandler(char const* arg, INT32U len) {
   dn_error_t     dnErr;
   int            l;
   int            saddr;
   
   
   //--- param 
   l = sscanf (arg, "%02x", &saddr);
   if (l < 1) {
      dnm_ucli_printf("!!! Usage !!!\r\n");
      dnm_ucli_printf("wraddr I2C_addr\r\n");
      return DN_ERR_INVALID;
   }
   else {
   // initialize I2C communication parameters
   i2c_app_v.i2cTransfer.slaveAddress    = saddr;
   return DN_ERR_NONE;
   }
   
}


//===== 'rdData' (read from I2C) CLI command

dn_error_t cli_readDataCmdHandler(char const* arg, INT32U len) {
   dn_error_t     dnErr;
   int            l;
   int            dtlen;
   
   
   //--- param 
   l = sscanf (arg, "%02x", &dtlen);
   if (l < 1) {
      dnm_ucli_printf("!!! Usage !!!\r\n");
      dnm_ucli_printf("rddata read_Len\r\n");
      return DN_ERR_INVALID;
   }
   else {
      // initialize I2C communication parameters
      //i2c_app_v.i2cTransfer.slaveAddress    = saddr;
      //i2c_app_v.i2cTransfer.slaveAddress    = I2C_SLAVE_ADDR;
      i2c_app_v.i2cTransfer.writeBuf        = NULL;
      i2c_app_v.i2cTransfer.readBuf         = i2c_app_v.i2cBuffer;
      i2c_app_v.i2cTransfer.writeLen        = 0;
      i2c_app_v.i2cTransfer.readLen         = dtlen;
      i2c_app_v.i2cTransfer.timeout         = 0xff;
      
      // initiate transaction
      dnErr = dn_ioctl(
         DN_I2C_DEV_ID,
         DN_IOCTL_I2C_TRANSFER,
         &i2c_app_v.i2cTransfer,
         sizeof(i2c_app_v.i2cTransfer)
      );
      
      if (dnErr==DN_ERR_NONE) {
         dnm_ucli_printf("Read Data = 0x%02x 0x%02x\r\n",i2c_app_v.i2cBuffer[0],i2c_app_v.i2cBuffer[1]);
      } else {
         dnm_ucli_printf("I2C Device Read Error!\r\n");
      }
      return DN_ERR_NONE;
   }
}


dn_error_t cli_resetCmdHandler(char const* buf, INT32U len) {
   INT8U      rc;
    
   dnm_ucli_printf("Resetting...\r\n\n");
   OSTimeDly(500);
    
   // send reset to stack
   dnm_loc_resetCmd(&rc);  
    
   return(rc);
}


//=============================================================================
//=========================== install a kernel header =========================
//=============================================================================

/**
A kernel header is a set of bytes prepended to the actual binary image of this
application. Thus header is needed for your application to start running.
*/

DN_CREATE_EXE_HDR(DN_VENDOR_ID_NOT_SET,
                  DN_APP_ID_NOT_SET,
                  VER_MAJOR,
                  VER_MINOR,
                  VER_PATCH,
                  VER_BUILD);
