import { OpenAPIV3 } from 'openapi-types';

export const openApiSpec: OpenAPIV3.Document = {
  openapi: '3.0.0',
  info: {
    title: 'Fleet Manager Driver API',
    version: '1.0.0',
    description: 'API for driver dashboard functionality including HOS tracking, load management, and location services',
    contact: {
      name: 'API Support',
      email: 'api@fleetmanager.com',
    },
    license: {
      name: 'MIT',
      url: 'https://opensource.org/licenses/MIT',
    },
  },
  servers: [
    {
      url: 'http://localhost:3000',
      description: 'Development server',
    },
    {
      url: 'https://api.fleetmanager.com',
      description: 'Production server',
    },
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
      },
    },
    schemas: {
      Error: {
        type: 'object',
        properties: {
          error: {
            type: 'object',
            properties: {
              code: { type: 'string' },
              message: { type: 'string' },
              details: { type: 'object' },
            },
          },
        },
      },
      HOSEntry: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'uuid' },
          driverId: { type: 'string', format: 'uuid' },
          status: {
            type: 'string',
            enum: ['off_duty', 'sleeper_berth', 'driving', 'on_duty_not_driving'],
          },
          startTime: { type: 'string', format: 'date-time' },
          endTime: { type: 'string', format: 'date-time', nullable: true },
          location: {
            type: 'object',
            properties: {
              latitude: { type: 'number' },
              longitude: { type: 'number' },
              address: { type: 'string', nullable: true },
            },
          },
          notes: { type: 'string', nullable: true },
          createdAt: { type: 'string', format: 'date-time' },
          updatedAt: { type: 'string', format: 'date-time' },
        },
      },
      Load: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'uuid' },
          loadNumber: { type: 'string' },
          status: {
            type: 'string',
            enum: ['offered', 'accepted', 'in_transit', 'completed', 'cancelled'],
          },
          driverId: { type: 'string', format: 'uuid', nullable: true },
          stops: {
            type: 'array',
            items: { $ref: '#/components/schemas/LoadStop' },
          },
          totalDistance: { type: 'number' },
          estimatedDuration: { type: 'number' },
          cargo: {
            type: 'object',
            properties: {
              description: { type: 'string' },
              weight: { type: 'number' },
              pieces: { type: 'number', nullable: true },
              hazmat: { type: 'boolean' },
            },
          },
          rate: { type: 'number' },
          currency: { type: 'string' },
        },
      },
      LoadStop: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'uuid' },
          type: { type: 'string', enum: ['pickup', 'delivery'] },
          sequence: { type: 'number' },
          location: {
            type: 'object',
            properties: {
              name: { type: 'string' },
              address: { type: 'string' },
              city: { type: 'string' },
              state: { type: 'string' },
              zip: { type: 'string' },
              latitude: { type: 'number', nullable: true },
              longitude: { type: 'number', nullable: true },
            },
          },
          scheduledTime: { type: 'string', format: 'date-time' },
          status: {
            type: 'string',
            enum: ['pending', 'arrived', 'completed', 'skipped'],
          },
        },
      },
    },
  },
  security: [{ bearerAuth: [] }],
  paths: {
    '/api/driver/{driverId}/hos': {
      get: {
        summary: 'Get HOS entries for driver',
        tags: ['HOS'],
        parameters: [
          {
            name: 'driverId',
            in: 'path',
            required: true,
            schema: { type: 'string', format: 'uuid' },
          },
          {
            name: 'startDate',
            in: 'query',
            schema: { type: 'string', format: 'date-time' },
          },
          {
            name: 'endDate',
            in: 'query',
            schema: { type: 'string', format: 'date-time' },
          },
        ],
        responses: {
          '200': {
            description: 'HOS entries retrieved successfully',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    entries: {
                      type: 'array',
                      items: { $ref: '#/components/schemas/HOSEntry' },
                    },
                    currentStatus: { type: 'string' },
                  },
                },
              },
            },
          },
          '401': {
            description: 'Unauthorized',
            content: {
              'application/json': {
                schema: { $ref: '#/components/schemas/Error' },
              },
            },
          },
        },
      },
    },
    '/api/driver/{driverId}/hos/status': {
      post: {
        summary: 'Change HOS status',
        tags: ['HOS'],
        parameters: [
          {
            name: 'driverId',
            in: 'path',
            required: true,
            schema: { type: 'string', format: 'uuid' },
          },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['status', 'location', 'timestamp'],
                properties: {
                  status: {
                    type: 'string',
                    enum: ['off_duty', 'sleeper_berth', 'driving', 'on_duty_not_driving'],
                  },
                  location: {
                    type: 'object',
                    properties: {
                      latitude: { type: 'number' },
                      longitude: { type: 'number' },
                    },
                  },
                  timestamp: { type: 'string', format: 'date-time' },
                  notes: { type: 'string' },
                },
              },
            },
          },
        },
        responses: {
          '201': {
            description: 'Status changed successfully',
            content: {
              'application/json': {
                schema: { $ref: '#/components/schemas/HOSEntry' },
              },
            },
          },
          '400': {
            description: 'Validation error or HOS violation',
            content: {
              'application/json': {
                schema: { $ref: '#/components/schemas/Error' },
              },
            },
          },
        },
      },
    },
  },
  tags: [
    { name: 'HOS', description: 'Hours of Service management' },
    { name: 'Loads', description: 'Load management' },
    { name: 'Location', description: 'Location tracking' },
    { name: 'Violations', description: 'HOS violations' },
  ],
};
