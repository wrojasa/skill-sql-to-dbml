USE [BD_DEMO]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Cliente](
	[IdCliente] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[Nit] [varchar](20) COLLATE Modern_Spanish_CI_AS NOT NULL,
	[RazonSocial] [nvarchar](200) NOT NULL,
	[FechaRegistro] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_Cliente] PRIMARY KEY CLUSTERED
(
	[IdCliente] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [UQ_Cliente_Nit] UNIQUE NONCLUSTERED
(
	[Nit] ASC
) ON [PRIMARY]
) ON [PRIMARY]
GO
CREATE TABLE [dbo].[Contrato](
	[IdContrato] [int] IDENTITY(1,1) NOT NULL,
	[IdCliente] [int] NOT NULL,
	[Codigo] [varchar](30) NOT NULL,
	[Valor] [numeric](18, 2) NOT NULL,
	[Observaciones] [nvarchar](max) NULL,
	[IdContratoPadre] [int] NULL,
	[ValorConIva]  AS ([Valor]*(1.19)) PERSISTED,
 CONSTRAINT [PK_Contrato] PRIMARY KEY CLUSTERED
(
	[IdContrato] ASC
) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
CREATE TABLE [dbo].[ContratoPoliza](
	[IdContrato] [int] NOT NULL,
	[NumeroPoliza] [varchar](40) NOT NULL,
	[Aseguradora] [nvarchar](120) NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ContratoPoliza] ADD CONSTRAINT [PK_ContratoPoliza] PRIMARY KEY CLUSTERED ([IdContrato] ASC) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Contrato] ADD CONSTRAINT [DF_Contrato_Valor] DEFAULT ((0)) FOR [Valor]
GO
ALTER TABLE [dbo].[Contrato]  WITH CHECK ADD  CONSTRAINT [FK_Contrato_Cliente] FOREIGN KEY([IdCliente])
REFERENCES [dbo].[cliente] ([idcliente])
GO
ALTER TABLE [dbo].[Contrato] CHECK CONSTRAINT [FK_Contrato_Cliente]
GO
ALTER TABLE [dbo].[Contrato]  WITH CHECK ADD  CONSTRAINT [FK_Contrato_Padre] FOREIGN KEY([IdContratoPadre])
REFERENCES [dbo].[Contrato] ([IdContrato])
GO
ALTER TABLE [dbo].[Contrato] CHECK CONSTRAINT [FK_Contrato_Padre]
GO
ALTER TABLE [dbo].[ContratoPoliza]  WITH CHECK ADD  CONSTRAINT [FK_ContratoPoliza_Contrato] FOREIGN KEY([IdContrato])
REFERENCES [dbo].[Contrato] ([IdContrato])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[ContratoPoliza] CHECK CONSTRAINT [FK_ContratoPoliza_Contrato]
GO
ALTER TABLE [dbo].[Contrato]  WITH CHECK ADD  CONSTRAINT [CK_Contrato_Valor] CHECK  (([Valor]>=(0)))
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Contratos firmados con clientes' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Contrato'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Codigo interno del contrato' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Contrato', @level2type=N'COLUMN',@level2name=N'Codigo'
GO
